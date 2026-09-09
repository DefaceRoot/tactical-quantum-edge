using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Xml;
using System.Xml.Linq;

namespace TqeDemo
{
    public sealed class ConnectionOptions
    {
        public string ServerAddress;
        public string ServerName;
        public string ClientPfxPath;
        public string TrustPfxPath;
        public string ClientPassword;
        public string TrustPassword;
        public string DisplayName;
        public int Port;
        public CancellationToken CancellationToken;
    }

    public static class Runner
    {
        private const int MaxEventBytes = 65536;
        private static readonly UTF8Encoding Utf8 = new UTF8Encoding(false, true);

        public static int Probe(ConnectionOptions options)
        {
            using (Session session = new Session(options, "probe", null))
            {
                session.Transport.Start();
                while (!session.Control.Stopped)
                {
                    if (session.Transport.Poll(false))
                    {
                        session.Record("probe_authenticated", null);
                        return 0;
                    }
                    session.Control.Wait(100);
                }
                return 130;
            }
        }

        public static int Replay(ConnectionOptions options, string inputFile, bool refreshTimes,
            double speed, bool loop, string logPath)
        {
            if (Double.IsNaN(speed) || Double.IsInfinity(speed) || speed <= 0)
                throw new ArgumentException("Replay speed must be finite and greater than zero.");
            using (FileStream input = new FileStream(inputFile, FileMode.Open, FileAccess.Read, FileShare.Read))
            using (Session session = new Session(options, "replay", logPath))
            {
                DateTimeOffset first = DateTimeOffset.MinValue;
                DateTimeOffset previous = DateTimeOffset.MinValue;
                long count = 0;
                Framer preflight = new Framer(input, true);
                byte[] bytes;
                while ((bytes = preflight.Next()) != null)
                {
                    if (session.Control.Stopped) return 130;
                    CotEvent item = Parse(bytes);
                    if (count == 0) first = item.Time;
                    else if (item.Time < previous)
                        throw new InvalidDataException("Replay event times must be nondecreasing; input is not reordered.");
                    previous = item.Time;
                    count++;
                }
                if (count == 0) throw new InvalidDataException("The input contains no CoT events.");
                session.Record("input_validated", new Dictionary<string, object> {
                    { "inputEvents", count }, { "refreshTimes", refreshTimes }, { "speed", speed }
                });
                if (!session.WaitForConnection()) return 130;
                do
                {
                    input.Position = 0;
                    Framer frames = new Framer(input, true);
                    TimeSpan shift = refreshTimes ? DateTimeOffset.UtcNow - first : TimeSpan.Zero;
                    Stopwatch clock = Stopwatch.StartNew();
                    DateTimeOffset previousPlayback = first;
                    while (!session.Control.Stopped && (bytes = frames.Next()) != null)
                    {
                        CotEvent item = Parse(bytes);
                        double due = (item.Time - previousPlayback).TotalMilliseconds / speed;
                        while (!session.Control.Stopped && clock.Elapsed.TotalMilliseconds < due)
                        {
                            session.Transport.Poll(true);
                            session.Status();
                            session.Control.Wait((int)Math.Min(250, Math.Max(1, due - clock.Elapsed.TotalMilliseconds)));
                        }
                        if (session.Control.Stopped) break;
                        previousPlayback = item.Time;
                        if (refreshTimes) item = Rebase(item, shift);
                        session.Send(item);
                        clock.Restart();
                    }
                    session.Record("replay_iteration_finished", null);
                    if (loop && !session.Control.Stopped && previous == first) session.Control.Wait(1000);
                } while (loop && !session.Control.Stopped);
                return session.Control.Stopped ? 130 : 0;
            }
        }

        public static int Relay(ConnectionOptions options, string bindAddress, int udpPort, string logPath)
        {
            IPAddress address;
            if (!IPAddress.TryParse(bindAddress, out address))
                throw new ArgumentException("UDP bind address must be a numeric local IP address.");
            if (udpPort < 1 || udpPort > 65535) throw new ArgumentException("UDP port must be between 1 and 65535.");
            using (Session session = new Session(options, "relay", logPath))
            using (UdpClient udp = new UdpClient(new IPEndPoint(address, udpPort)))
            {
                udp.Client.ReceiveTimeout = 250;
                udp.Client.ReceiveBufferSize = 65536;
                session.Record("udp_listening", new Dictionary<string, object> {
                    { "notice", "One UTF-8 CoT event per datagram. UDP/kernel loss is not measurable here." }
                });
                session.Transport.Start();
                IPEndPoint source = null;
                while (!session.Control.Stopped)
                {
                    session.Transport.Poll(true);
                    session.Status();
                    byte[] bytes;
                    try { bytes = udp.Receive(ref source); }
                    catch (SocketException error)
                    {
                        if (error.SocketErrorCode == SocketError.TimedOut) continue;
                        throw;
                    }
                    CotEvent item;
                    try { item = Parse(bytes); }
                    catch (Exception error)
                    {
                        if (!(error is XmlException) && !(error is InvalidDataException) &&
                            !(error is DecoderFallbackException) && !(error is ArgumentException)) throw;
                        session.Dropped++;
                        session.Record("udp_invalid_dropped", new Dictionary<string, object> { { "bytes", bytes.Length } });
                        continue;
                    }
                    session.Receipt(item, "udp_received");
                    session.Send(item);
                }
                return 130;
            }
        }

        public static int Receive(ConnectionOptions options, string[] uids, string logPath)
        {
            HashSet<string> filter = uids == null || uids.Length == 0 ? null :
                new HashSet<string>(uids, StringComparer.Ordinal);
            using (Session session = new Session(options, "receive", logPath))
            {
                byte[] buffer = new byte[4096];
                while (!session.Control.Stopped)
                {
                    if (!session.WaitForConnection()) break;
                    Framer framer = new Framer(null, false);
                    try
                    {
                        while (!session.Control.Stopped && session.Transport.Stream != null)
                        {
                            SslStream stream = session.Transport.Stream;
                            IAsyncResult pending = stream.BeginRead(buffer, 0, buffer.Length, null, null);
                            using (WaitHandle ready = pending.AsyncWaitHandle)
                            {
                                while (!ready.WaitOne(250))
                                {
                                    session.Status();
                                    if (session.Control.Stopped) break;
                                }
                                if (session.Control.Stopped)
                                {
                                    stream.Dispose();
                                    try { stream.EndRead(pending); }
                                    catch (IOException) { }
                                    catch (ObjectDisposedException) { }
                                    catch (SocketException) { }
                                    break;
                                }
                                int read = stream.EndRead(pending);
                                if (read == 0) throw new IOException("TLS peer closed the receive stream.");
                                for (int index = 0; index < read; index++)
                                {
                                    byte[] complete = framer.Feed(buffer[index]);
                                    if (complete == null) continue;
                                    CotEvent item = Parse(complete);
                                    if (filter == null || filter.Contains(item.Uid))
                                        session.Receipt(item, "tls_received");
                                }
                            }
                        }
                    }
                    catch (Exception error)
                    {
                        if (!(error is IOException) && !(error is SocketException) &&
                            !(error is XmlException) && !(error is InvalidDataException) &&
                            !(error is DecoderFallbackException)) throw;
                        if (error is XmlException || error is InvalidDataException || error is DecoderFallbackException)
                            session.Dropped++;
                        session.Transport.Failed(error);
                    }
                }
                return 130;
            }
        }

        private sealed class CotEvent
        {
            internal byte[] Bytes;
            internal string Uid;
            internal DateTimeOffset Time;
            internal DateTimeOffset Start;
            internal DateTimeOffset Stale;
        }

        private static XmlReaderSettings XmlSettings()
        {
            return new XmlReaderSettings {
                DtdProcessing = DtdProcessing.Prohibit,
                XmlResolver = null,
                MaxCharactersInDocument = MaxEventBytes,
                MaxCharactersFromEntities = MaxEventBytes,
                IgnoreWhitespace = false,
                ConformanceLevel = ConformanceLevel.Document
            };
        }

        private static string XmlText(byte[] bytes)
        {
            int start = bytes.Length >= 3 && bytes[0] == 0xef && bytes[1] == 0xbb && bytes[2] == 0xbf ? 3 : 0;
            return Utf8.GetString(bytes, start, bytes.Length - start);
        }

        private static CotEvent Parse(byte[] bytes)
        {
            if (bytes.Length == 0 || bytes.Length > MaxEventBytes)
                throw new InvalidDataException("Each CoT event must be between 1 and 65536 UTF-8 bytes.");
            CotEvent item = null;
            using (StringReader text = new StringReader(XmlText(bytes)))
            using (XmlReader reader = XmlReader.Create(text, XmlSettings()))
            {
                while (reader.Read())
                {
                    if (reader.NodeType == XmlNodeType.XmlDeclaration)
                    {
                        string encoding = reader.GetAttribute("encoding");
                        if (!String.IsNullOrEmpty(encoding) && !String.Equals(encoding, "utf-8", StringComparison.OrdinalIgnoreCase))
                            throw new InvalidDataException("Only UTF-8 XML is supported.");
                    }
                    if (reader.Depth >= 64) throw new InvalidDataException("XML nesting exceeds 64 elements.");
                    if (reader.NodeType != XmlNodeType.Element || reader.Depth != 0) continue;
                    if (reader.Name != "event" || reader.NamespaceURI.Length != 0)
                        throw new InvalidDataException("Expected one unqualified CoT event element.");
                    Required(reader, "type");
                    item = new CotEvent {
                        Bytes = bytes, Uid = Required(reader, "uid"),
                        Time = Timestamp(reader, "time"), Start = Timestamp(reader, "start"),
                        Stale = Timestamp(reader, "stale")
                    };
                    if (item.Stale < item.Start) throw new InvalidDataException("CoT stale precedes start.");
                }
            }
            if (item == null) throw new InvalidDataException("Expected one CoT event element.");
            return item;
        }

        private static string Required(XmlReader reader, string name)
        {
            string value = reader.GetAttribute(name);
            if (String.IsNullOrWhiteSpace(value))
                throw new InvalidDataException("CoT event requires a nonempty " + name + " attribute.");
            return value;
        }

        private static DateTimeOffset Timestamp(XmlReader reader, string name)
        {
            string value = Required(reader, name);
            int t = value.IndexOf('T');
            bool zone = value.EndsWith("Z", StringComparison.Ordinal) ||
                (t >= 0 && (value.IndexOf('+', t) >= 0 || value.IndexOf('-', t) >= 0));
            if (!zone) throw new InvalidDataException("CoT " + name + " requires an explicit UTC offset.");
            try { return XmlConvert.ToDateTimeOffset(value).ToUniversalTime(); }
            catch (FormatException) { throw new InvalidDataException("CoT " + name + " is not a valid XML timestamp."); }
        }

        private static CotEvent Rebase(CotEvent item, TimeSpan shift)
        {
            XDocument document;
            using (StringReader text = new StringReader(XmlText(item.Bytes)))
            using (XmlReader reader = XmlReader.Create(text, XmlSettings()))
                document = XDocument.Load(reader, LoadOptions.PreserveWhitespace);
            try
            {
                item.Time += shift;
                item.Start += shift;
                item.Stale += shift;
            }
            catch (ArgumentOutOfRangeException) { throw new InvalidDataException("Rebased CoT timestamp is outside the supported date range."); }
            document.Root.SetAttributeValue("time", XmlConvert.ToString(item.Time));
            document.Root.SetAttributeValue("start", XmlConvert.ToString(item.Start));
            document.Root.SetAttributeValue("stale", XmlConvert.ToString(item.Stale));
            item.Bytes = Utf8.GetBytes(document.ToString(SaveOptions.DisableFormatting));
            if (item.Bytes.Length > MaxEventBytes) throw new InvalidDataException("Rebased CoT event exceeds 65536 bytes.");
            return item;
        }

        private sealed class Control : IDisposable
        {
            private readonly ManualResetEvent stop = new ManualResetEvent(false);
            private readonly ConsoleCancelEventHandler handler;
            private readonly CancellationTokenRegistration cancellationRegistration;
            internal bool Stopped { get { return stop.WaitOne(0); } }
            internal Control(CancellationToken cancellationToken)
            {
                cancellationRegistration = cancellationToken.Register(delegate { stop.Set(); });
                handler = delegate(object sender, ConsoleCancelEventArgs args) { args.Cancel = true; stop.Set(); };
                Console.CancelKeyPress += handler;
            }
            internal void Wait(int milliseconds) { stop.WaitOne(milliseconds); }
            public void Dispose()
            {
                Console.CancelKeyPress -= handler;
                cancellationRegistration.Dispose();
                stop.Dispose();
            }
        }

        private sealed class Session : IDisposable
        {
            internal readonly Control Control;
            internal readonly Link Transport;
            internal long Attempted;
            internal long Received;
            internal long Dropped;
            private long deliveryUnknown;
            private readonly string label;
            private readonly string mode;
            private readonly StreamWriter log;
            private readonly JavaScriptSerializer json = new JavaScriptSerializer();
            private DateTimeOffset? lastReceipt;
            private DateTimeOffset nextStatus = DateTimeOffset.UtcNow;

            internal Session(ConnectionOptions options, string mode, string logPath)
            {
                ValidateOptions(options);
                this.label = options.DisplayName;
                this.mode = mode;
                if (!String.IsNullOrWhiteSpace(logPath))
                    log = new StreamWriter(new FileStream(logPath, FileMode.CreateNew, FileAccess.Write, FileShare.Read), new UTF8Encoding(false)) { AutoFlush = true };
                try
                {
                    Control = new Control(options.CancellationToken);
                    Transport = new Link(options, this, mode == "replay" || mode == "relay");
                    Record("started", new Dictionary<string, object> {
                        { "notice", "Write attempts are not delivery. Receipt counts cover only this process and any UID filter. Revocation is not checked." }
                    });
                }
                catch
                {
                    if (Transport != null) Transport.Dispose();
                    if (Control != null) Control.Dispose();
                    if (log != null) log.Dispose();
                    throw;
                }
            }

            internal bool WaitForConnection()
            {
                while (!Control.Stopped)
                {
                    if (Transport.Poll(true)) return true;
                    Status();
                    Control.Wait(250);
                }
                return false;
            }

            internal void Send(CotEvent item)
            {
                if (!Transport.Poll(true))
                {
                    Dropped++;
                    Record("disconnected_dropped", Metadata(item));
                    return;
                }
                Attempted++;
                try
                {
                    Transport.Stream.Write(item.Bytes, 0, item.Bytes.Length);
                    Transport.Stream.Flush();
                }
                catch (Exception error)
                {
                    if (!(error is IOException) && !(error is SocketException)) throw;
                    deliveryUnknown++;
                    Record("write_failed_delivery_unknown", Metadata(item));
                    Transport.Failed(error);
                    return;
                }
                Record("write_completed_not_delivery", Metadata(item));
            }

            internal void Receipt(CotEvent item, string state)
            {
                DateTimeOffset arrival = DateTimeOffset.UtcNow;
                Dictionary<string, object> fields = Metadata(item);
                fields["arrivalUtc"] = Stamp(arrival);
                fields["receiptGapSeconds"] = lastReceipt.HasValue ? (object)(arrival - lastReceipt.Value).TotalSeconds : null;
                lastReceipt = arrival;
                Received++;
                Record(state, fields);
            }

            internal void Status()
            {
                if (DateTimeOffset.UtcNow < nextStatus) return;
                nextStatus = DateTimeOffset.UtcNow.AddSeconds(1);
                Record("status", null);
            }

            internal void Record(string state, Dictionary<string, object> fields)
            {
                Dictionary<string, object> record = fields ?? new Dictionary<string, object>();
                record["utc"] = Stamp(DateTimeOffset.UtcNow);
                record["displayName"] = label;
                record["mode"] = mode;
                record["state"] = state;
                record["connectionState"] = Transport != null && Transport.Stream != null ? "authenticated" : "disconnected";
                record["attempted"] = Attempted;
                record["received"] = Received;
                record["dropped"] = Dropped;
                record["failedWritesDeliveryUnknown"] = deliveryUnknown;
                record["lastReceiptUtc"] = lastReceipt.HasValue ? Stamp(lastReceipt.Value) : null;
                record["secondsSinceLastReceipt"] = lastReceipt.HasValue ? (object)(DateTimeOffset.UtcNow - lastReceipt.Value).TotalSeconds : null;
                string line = json.Serialize(record);
                if (log != null) log.WriteLine(line);
                Console.WriteLine(line);
            }

            public void Dispose()
            {
                try { Transport.Dispose(); Record("stopped", null); }
                finally { Control.Dispose(); if (log != null) log.Dispose(); }
            }
        }

        private static string Stamp(DateTimeOffset value) { return value.UtcDateTime.ToString("o", CultureInfo.InvariantCulture); }

        private static Dictionary<string, object> Metadata(CotEvent item)
        {
            string hash;
            using (SHA256 sha = SHA256.Create()) hash = BitConverter.ToString(sha.ComputeHash(item.Bytes)).Replace("-", "").ToLowerInvariant();
            return new Dictionary<string, object> {
                { "uid", item.Uid }, { "cotTime", Stamp(item.Time) }, { "bytes", item.Bytes.Length }, { "sha256", hash }
            };
        }

        private static void ValidateOptions(ConnectionOptions options)
        {
            if (options == null) throw new ArgumentNullException("options");
            if (String.IsNullOrWhiteSpace(options.ServerAddress) || String.IsNullOrWhiteSpace(options.ServerName))
                throw new ArgumentException("Both server address and explicit TLS server name are required.");
            if (options.Port < 1 || options.Port > 65535) throw new ArgumentException("TLS port must be between 1 and 65535.");
            if (String.IsNullOrWhiteSpace(options.ClientPfxPath) || String.IsNullOrWhiteSpace(options.TrustPfxPath))
                throw new ArgumentException("Client and trust PKCS#12 paths are required.");
        }

        private sealed class Link : IDisposable
        {
            private readonly ConnectionOptions options;
            private readonly Session session;
            private readonly bool drainInbound;
            private readonly X509Certificate2Collection client = new X509Certificate2Collection();
            private readonly X509Certificate2Collection trust = new X509Certificate2Collection();
            private readonly HashSet<string> anchors = new HashSet<string>(StringComparer.Ordinal);
            private readonly object gate = new object();
            private X509Certificate2 identity;
            private TcpClient socket;
            private Task<SslStream> connecting;
            private Task<Exception> draining;
            private DateTimeOffset nextConnect = DateTimeOffset.MinValue;
            private DateTimeOffset? disconnectedAt;
            private bool disposed;
            internal SslStream Stream;

            internal Link(ConnectionOptions options, Session session, bool drainInbound)
            {
                this.options = options;
                this.session = session;
                this.drainInbound = drainInbound;
                try
                {
                    // Windows SChannel requires a user key container; do not persist it or install certificates in an OS store.
                    client.Import(options.ClientPfxPath, options.ClientPassword, X509KeyStorageFlags.UserKeySet);
                    trust.Import(options.TrustPfxPath, options.TrustPassword, X509KeyStorageFlags.EphemeralKeySet);
                    foreach (X509Certificate2 certificate in client)
                    {
                        if (!certificate.HasPrivateKey || IsCa(certificate)) continue;
                        if (identity != null) throw new InvalidDataException("Client PKCS#12 contains multiple private-key identities.");
                        identity = certificate;
                    }
                    if (identity == null) throw new InvalidDataException("Client PKCS#12 has no non-CA certificate with a private key.");
                    DateTime now = DateTime.UtcNow;
                    if (now < identity.NotBefore.ToUniversalTime() || now > identity.NotAfter.ToUniversalTime())
                        throw new InvalidDataException("Client certificate is not currently valid.");
                    foreach (X509Certificate2 certificate in trust)
                    {
                        if (IsCa(certificate) && Equal(certificate.SubjectName.RawData, certificate.IssuerName.RawData))
                            anchors.Add(Convert.ToBase64String(certificate.RawData));
                    }
                    if (anchors.Count == 0) throw new InvalidDataException("Trust PKCS#12 must contain a self-issued CA root.");
                }
                catch { ReleaseCertificates(); throw; }
            }

            private static bool IsCa(X509Certificate2 certificate)
            {
                foreach (X509Extension extension in certificate.Extensions)
                    if (extension.Oid.Value == "2.5.29.19") return new X509BasicConstraintsExtension(extension, extension.Critical).CertificateAuthority;
                return false;
            }

            private static bool Equal(byte[] left, byte[] right)
            {
                if (left.Length != right.Length) return false;
                for (int i = 0; i < left.Length; i++) if (left[i] != right[i]) return false;
                return true;
            }

            private bool ValidateServer(object sender, X509Certificate certificate, X509Chain supplied, SslPolicyErrors errors)
            {
                if (certificate == null || (errors & (SslPolicyErrors.RemoteCertificateNotAvailable | SslPolicyErrors.RemoteCertificateNameMismatch)) != 0)
                    return false;
                using (X509Certificate2 leaf = new X509Certificate2(certificate))
                using (X509Chain chain = new X509Chain())
                {
                    chain.ChainPolicy.RevocationMode = X509RevocationMode.NoCheck;
                    chain.ChainPolicy.VerificationFlags = X509VerificationFlags.AllowUnknownCertificateAuthority;
                    chain.ChainPolicy.UrlRetrievalTimeout = TimeSpan.Zero;
                    chain.ChainPolicy.ApplicationPolicy.Add(new Oid("1.3.6.1.5.5.7.3.1"));
                    chain.ChainPolicy.ExtraStore.AddRange(trust);
                    if (supplied != null)
                        foreach (X509ChainElement element in supplied.ChainElements) chain.ChainPolicy.ExtraStore.Add(element.Certificate);
                    if (!chain.Build(leaf) || chain.ChainElements.Count == 0) return false;
                    foreach (X509ChainStatus status in chain.ChainStatus)
                        if (status.Status != X509ChainStatusFlags.NoError && status.Status != X509ChainStatusFlags.UntrustedRoot) return false;
                    // ExtraStore is not a trust store: the actual terminal certificate must be an explicit anchor.
                    X509Certificate2 root = chain.ChainElements[chain.ChainElements.Count - 1].Certificate;
                    return anchors.Contains(Convert.ToBase64String(root.RawData));
                }
            }

            internal void Start()
            {
                if (connecting != null || Stream != null || disposed) return;
                session.Record("connecting", null);
                connecting = Task.Factory.StartNew<SslStream>(Connect, CancellationToken.None, TaskCreationOptions.None, TaskScheduler.Default);
            }

            private SslStream Connect()
            {
                TcpClient tcp = new TcpClient();
                SslStream tls = null;
                try
                {
                    lock (gate)
                    {
                        if (disposed) throw new ObjectDisposedException("TLS connection");
                        socket = tcp;
                    }
                    tcp.NoDelay = true;
                    tcp.SendTimeout = 2000;
                    tcp.ReceiveTimeout = 10000;
                    IAsyncResult attempt = tcp.BeginConnect(options.ServerAddress, options.Port, null, null);
                    using (WaitHandle wait = attempt.AsyncWaitHandle)
                    {
                        if (!wait.WaitOne(10000)) throw new IOException("TCP connection timed out after 10 seconds.");
                        tcp.EndConnect(attempt);
                    }
                    tls = new SslStream(tcp.GetStream(), false, ValidateServer,
                        delegate(object sender, string host, X509CertificateCollection certificates, X509Certificate remote, string[] issuers) { return identity; });
                    tls.ReadTimeout = 10000;
                    tls.WriteTimeout = 2000;
                    tls.AuthenticateAsClient(options.ServerName, client, SslProtocols.Tls12, false);
                    if (!tls.IsMutuallyAuthenticated)
                        throw new AuthenticationException("The TLS server did not authenticate the supplied client certificate.");
                    tls.ReadTimeout = Timeout.Infinite;
                    lock (gate)
                    {
                        if (disposed) throw new ObjectDisposedException("TLS connection");
                    }
                    return tls;
                }
                catch { if (tls != null) tls.Dispose(); tcp.Close(); throw; }
            }

            internal bool Poll(bool retry)
            {
                if (draining != null && draining.IsCompleted)
                {
                    Failed(draining.Result);
                    return false;
                }
                if (Stream != null) return true;
                if (connecting == null && DateTimeOffset.UtcNow >= nextConnect) Start();
                if (connecting == null || !connecting.IsCompleted) return false;
                Task<SslStream> completed = connecting;
                connecting = null;
                try { Stream = completed.GetAwaiter().GetResult(); }
                catch (Exception error)
                {
                    Failed(error);
                    if (!retry) throw new IOException("TLS probe failed. Check the endpoint, TLS server name, client identity and supplied CA trust.", error);
                    return false;
                }
                using (X509Certificate2 server = new X509Certificate2(Stream.RemoteCertificate))
                {
                    session.Record("tls_authenticated", new Dictionary<string, object> {
                        { "protocol", Stream.SslProtocol.ToString() }, { "serverSubject", server.Subject },
                        { "serverIssuer", server.Issuer }, { "serverCertificateSha256", CertificateHash(server) },
                        { "serverNotAfterUtc", server.NotAfter.ToUniversalTime().ToString("o", CultureInfo.InvariantCulture) },
                        { "transportInterruptionSeconds", disconnectedAt.HasValue ? (object)(DateTimeOffset.UtcNow - disconnectedAt.Value).TotalSeconds : null }
                    });
                }
                if (drainInbound) draining = Drain(Stream);
                disconnectedAt = null;
                return true;
            }

            private static async Task<Exception> Drain(SslStream stream)
            {
                byte[] buffer = new byte[4096];
                try
                {
                    while (await stream.ReadAsync(buffer, 0, buffer.Length).ConfigureAwait(false) != 0) { }
                    return new IOException("TLS peer closed the sender stream.");
                }
                catch (Exception error) { return error; }
            }

            private static string CertificateHash(X509Certificate2 certificate)
            {
                using (SHA256 sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(certificate.RawData)).Replace("-", "").ToLowerInvariant();
            }

            internal void Failed(Exception error)
            {
                draining = null;
                if (Stream != null) { Stream.Dispose(); Stream = null; }
                lock (gate) { if (socket != null) { socket.Close(); socket = null; } }
                if (!disconnectedAt.HasValue) disconnectedAt = DateTimeOffset.UtcNow;
                nextConnect = DateTimeOffset.UtcNow.AddSeconds(2);
                session.Record("transport_failed", new Dictionary<string, object> { { "errorType", error.GetType().Name }, { "notice", "Reconnect in 2 seconds; no queued event replay." } });
            }

            private void ReleaseCertificates()
            {
                foreach (X509Certificate2 certificate in client) certificate.Dispose();
                foreach (X509Certificate2 certificate in trust) certificate.Dispose();
            }

            public void Dispose()
            {
                lock (gate)
                {
                    disposed = true;
                    if (socket != null) { socket.Close(); socket = null; }
                }
                if (Stream != null) { Stream.Dispose(); Stream = null; }
                Task<SslStream> pending = connecting;
                if (pending == null) ReleaseCertificates();
                else pending.ContinueWith(delegate(Task<SslStream> task) {
                    if (task.Status == TaskStatus.RanToCompletion) task.Result.Dispose();
                    else if (task.IsFaulted) { AggregateException ignored = task.Exception; }
                    ReleaseCertificates();
                }, TaskScheduler.Default);
            }
        }

        private sealed class Framer
        {
            private readonly Stream input;
            private readonly bool allowWrapper;
            private readonly byte[] buffer = new byte[4096];
            private readonly MemoryStream token = new MemoryStream();
            private readonly Stack<string> elements = new Stack<string>();
            private MemoryStream current;
            private int offset;
            private int available;
            private byte quote;
            private bool inToken;
            private bool wrapperSeen;
            private bool wrapperClosed;
            private bool fragmentSeen;
            private int bom;

            internal Framer(Stream input, bool allowWrapper) { this.input = input; this.allowWrapper = allowWrapper; }

            internal byte[] Next()
            {
                while (true)
                {
                    if (offset == available)
                    {
                        available = input.Read(buffer, 0, buffer.Length);
                        offset = 0;
                        if (available == 0)
                        {
                            if (inToken || current != null || elements.Count != 0 || bom == 1 || bom == 2)
                                throw new InvalidDataException("Truncated XML input.");
                            return null;
                        }
                    }
                    byte[] result = Feed(buffer[offset++]);
                    if (result != null) return result;
                }
            }

            internal byte[] Feed(byte value)
            {
                if (bom < 3)
                {
                    if (bom == 0 && value != 0xef) bom = 3;
                    else
                    {
                        byte expected = bom == 0 ? (byte)0xef : bom == 1 ? (byte)0xbb : (byte)0xbf;
                        if (value != expected) throw new InvalidDataException("Input must be UTF-8 XML.");
                        bom++;
                        return null;
                    }
                }
                if (current != null)
                {
                    if (current.Length >= MaxEventBytes) throw new InvalidDataException("CoT event exceeds 65536 bytes.");
                    current.WriteByte(value);
                }
                if (!inToken)
                {
                    if (value == '<') { inToken = true; token.SetLength(0); token.WriteByte(value); quote = 0; }
                    else if (current == null && value != ' ' && value != '\r' && value != '\n' && value != '\t')
                        throw new InvalidDataException("Only whitespace is allowed outside CoT events.");
                    return null;
                }
                if (token.Length >= MaxEventBytes) throw new InvalidDataException("XML token exceeds 65536 bytes.");
                token.WriteByte(value);
                byte[] data = token.GetBuffer();
                int length = (int)token.Length;
                if (length >= 2 && data[1] == '!')
                {
                    bool comment = Prefix(data, length, "<!--");
                    bool cdata = Prefix(data, length, "<![CDATA[");
                    if (!comment && !cdata) throw new InvalidDataException("DTD and XML declarations other than comments/CDATA are prohibited.");
                    if (comment && length >= 4 && Ends(data, length, "-->")) return CompleteToken();
                    if (cdata && length >= 9 && Ends(data, length, "]]>")) return CompleteToken();
                    return null;
                }
                if (length >= 2 && data[1] == '?')
                {
                    if (Ends(data, length, "?>")) return CompleteToken();
                    return null;
                }
                if (quote != 0) { if (value == quote) quote = 0; return null; }
                if (value == '\'' || value == '"') { quote = value; return null; }
                return value == '>' ? CompleteToken() : null;
            }

            private byte[] CompleteToken()
            {
                inToken = false;
                byte[] bytes = token.ToArray();
                string text = Utf8.GetString(bytes);
                if (current == null && wrapperSeen && text.StartsWith("<?xml", StringComparison.Ordinal) &&
                    text.Length > 5 && Char.IsWhiteSpace(text[5]))
                    throw new InvalidDataException("An XML declaration cannot appear inside or after the wrapper.");
                if (text.StartsWith("<!--", StringComparison.Ordinal) || text.StartsWith("<?", StringComparison.Ordinal))
                {
                    if (current == null) ValidateOutsideToken(text);
                    return null;
                }
                if (text.StartsWith("<![CDATA[", StringComparison.Ordinal))
                {
                    if (current == null) throw new InvalidDataException("CDATA outside a CoT event is not supported.");
                    return null;
                }
                bool closing = text.StartsWith("</", StringComparison.Ordinal);
                bool empty = text.EndsWith("/>", StringComparison.Ordinal);
                int start = closing ? 2 : 1;
                int end = start;
                while (end < text.Length && !Char.IsWhiteSpace(text[end]) && text[end] != '/' && text[end] != '>') end++;
                string name = text.Substring(start, end - start);
                XmlConvert.VerifyName(name);
                if (closing)
                {
                    if (text.Substring(end, text.Length - end - 1).Trim().Length != 0 || elements.Count == 0 || elements.Pop() != name)
                        throw new InvalidDataException("Mismatched XML closing element.");
                    if (current != null && elements.Count == (wrapperSeen ? 1 : 0)) return FinishEvent();
                    if (current == null) wrapperClosed = true;
                    return null;
                }
                if (current == null)
                {
                    if (wrapperClosed) throw new InvalidDataException("Content follows the closed XML wrapper.");
                    if (name == "event")
                    {
                        fragmentSeen = true;
                        current = new MemoryStream();
                        current.Write(bytes, 0, bytes.Length);
                    }
                    else
                    {
                        if (!allowWrapper || wrapperSeen || fragmentSeen || elements.Count != 0)
                            throw new InvalidDataException("Expected CoT event fragments or one wrapper with direct event children.");
                        ValidateWrapper(text, name, empty);
                        wrapperSeen = true;
                        if (empty) wrapperClosed = true;
                    }
                }
                if (!empty)
                {
                    elements.Push(name);
                    if (elements.Count > 64) throw new InvalidDataException("XML nesting exceeds 64 elements.");
                }
                else if (current != null && elements.Count == (wrapperSeen ? 1 : 0)) return FinishEvent();
                return null;
            }

            private byte[] FinishEvent()
            {
                byte[] bytes = current.ToArray();
                current.Dispose();
                current = null;
                return bytes;
            }

            private static void ValidateWrapper(string text, string name, bool empty)
            {
                using (StringReader source = new StringReader(empty ? text : text + "</" + name + ">"))
                using (XmlReader reader = XmlReader.Create(source, XmlSettings()))
                {
                    XElement wrapper = XElement.Load(reader);
                    foreach (XAttribute attribute in wrapper.Attributes())
                        if (attribute.IsNamespaceDeclaration)
                            throw new InvalidDataException("Wrapper namespace declarations are unsupported; each CoT event must be namespace-self-contained.");
                }
            }

            private static void ValidateOutsideToken(string text)
            {
                string document = text.StartsWith("<?xml", StringComparison.Ordinal) ? text + "<root/>" : "<root>" + text + "</root>";
                using (StringReader source = new StringReader(document))
                using (XmlReader reader = XmlReader.Create(source, XmlSettings()))
                {
                    XDocument parsed = XDocument.Load(reader);
                    if (parsed.Declaration != null && !String.IsNullOrEmpty(parsed.Declaration.Encoding) &&
                        !String.Equals(parsed.Declaration.Encoding, "utf-8", StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException("Only UTF-8 XML is supported.");
                }
            }

            private static bool Prefix(byte[] bytes, int length, string expected)
            {
                for (int index = 0; index < Math.Min(length, expected.Length); index++)
                    if (bytes[index] != expected[index]) return false;
                return true;
            }

            private static bool Ends(byte[] bytes, int length, string expected)
            {
                if (length < expected.Length) return false;
                for (int index = 0; index < expected.Length; index++)
                    if (bytes[length - expected.Length + index] != expected[index]) return false;
                return true;
            }
        }
    }
}
