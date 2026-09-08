# Architecture

## Intended topology

```text
Mission client A -- IEG A -- primary Ethernet or Wi-Fi uplink --+
                         \-- cellular puck alternate --------+-- CISEN PQC SDN
                                                             |   private addressing
Mission client B -- IEG B -- independent working uplink -------+   randomized relay paths
                                                             |
                                                       Service VM(s)
                                                       - TAK server
                                                       - video distribution
                                                       - shared-folder service
```

This is a deployment plan, not an observed wiring diagram. The supplied equipment is two IEGs and one cellular puck. VM availability, router interfaces and actual uplinks must be established on site. Keep IEG B and the service VM reachable while deliberately breaking only IEG A's primary transport. Do not put both paths behind the same failed upstream.

The team's CISEN design uses a global private addressing scheme and randomized relay selection. Private means routable within the authorized overlay, not globally reachable public addressing. Keep endpoint identities and mission-service addresses stable when outer transport addresses change. Check overlap with the venue LAN and puck subnet before assigning addresses. No real infrastructure addresses belong in public examples.

## Separate responsibilities

| Layer | Responsibility | Evidence |
|---|---|---|
| Underlay | Detect loss, choose an available transport, reach the overlay peer | Interface state, reachability and selected egress |
| CISEN security | Authenticate peers, establish a fresh PQ-derived secret, install the new traffic keys, prohibit downgrade | Correlated non-secret key-establishment and key-install events on both peers |
| Overlay routing | Preserve authorized private destinations and update allowed paths | Route generation, endpoint identity and authorized reachability |
| Mission application | Resume or continue according to its protocol | Received sequence numbers, fresh track age, decoded video frames, matching file hashes |

Reuse the IEG's existing transport manager. Do not install a competing routing manager during the event without checking its firewall marks, OpenWrt version and CISEN integration. OpenWrt's current documentation distinguishes iptables and nftables variants of mwan3 and warns about version compatibility. Multi-WAN failover is not channel bonding. [S5](sources.md)

## Recovery contract

```text
Protected operation
  -> interruption detected
  -> mission egress held while alternate transport is selected
  -> peer authenticated and fresh PQ key establishment completed
  -> new key epoch installed and confirmed
  -> authorized mission egress released
  -> application recovery measured
```

If key establishment or peer authentication fails, mission traffic must remain blocked. Permit only the control traffic needed to restore the secure connection. A connection that recovers using an earlier valid epoch may still be encrypted, but it does not prove the requested fresh-PQ-handshake behavior. Do not weaken a working CISEN protocol by improvising cryptography or merely restarting WireGuard.

An implementation review must establish how CISEN binds the recovered session to the authenticated peer, how fresh secrets are derived and confirmed, how stale or replayed exchanges are rejected, and how the old traffic epoch retires. Also establish whether peer authentication is classical, hybrid or post-quantum. ML-KEM supplies key establishment, not signatures or a complete authenticated protocol. [S3](sources.md)

WireGuard is not post-quantum secure by default. Its documentation describes layering a PQ handshake and installing the resulting secret in its PSK slot. Its roaming can change outer endpoints without an additional authentication round trip. CISEN's actual integration must be inspected rather than inferred from stock WireGuard. [S4](sources.md)

## What constitutes evidence

Capture a run ID, implementation build, negotiated algorithm, pseudonymous peer ID, transport generation, key epoch, authentication result, completion time and key-install acknowledgement. Correlate both ends and the first received application message after interruption. Never log private keys, PSKs, shared secrets or decapsulation keys.

Packet sizes, encrypted packet captures and `wg show` are supporting observations, not proof that ML-KEM ran correctly. Test the negative case by preventing fresh key establishment in an isolated, authorized setup. Confirm that application traffic stays blocked rather than falling back to a classical-only or unprotected path. No cryptographic certification is implied.

## Traffic semantics

- CoT tracks use stable track identities and valid time/start/stale values. Measure freshness at the receiver. Old packets must not masquerade as current positions.
- UDP can lose packets during a break. Report that loss. Durable delivery requires an application mechanism such as acknowledgement and replay; a tunnel does not supply it.
- Live video may freeze or lose frames. Measure the last decoded pre-break frame to the first fresh post-break frame. A prerecorded clip proves repeatability, not live sensor continuity.
- Shared-folder transfers need the actual application's retry or resume behavior. Verify complete received files against the input manifest. A matching SHA-256 detects corruption against a trusted manifest; it does not authenticate the sender.

## Limits to disclose

One cellular puck is one cellular failure domain, even when it offers Ethernet and Wi-Fi attachments. Do not describe two attachments to the same carrier link as independent backhauls. No satellite link, RF jamming, autonomous disconnected delivery, VM failover, or production scalability is established by this equipment alone.

Randomized paths do not prove anonymity or conceal timing, traffic volume or all topology relationships. Keep a redacted judge view separate from the authenticated operator view. The service VM remains a dependency and potential single point of failure. The live demo tests transport interruption, not every infrastructure failure.
