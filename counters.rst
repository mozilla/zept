Linux network stack statistics
==============================

Here is how you determine the number of dropped packets and correctly calculate the packet loss.

Some of these counters do not show drops but they should stay zero. If they don't you have a configuration problem.

General definitions and equations
---------------------------------

The term "successfully received packet" ought to be understood as packet has been delivered to the application layer and attached to a socket buffer. Sockets have own statistics that is not reflected in counters below. This is also true for the AF_Packet socket.

:ipackets:
    Number of successfully received packets
:ibytes:
    Number of successfully received bytes
:imissed:
    Number of "missed" i.e. packets dropped because of performance reasons. Those packets were valid.

Intel
.....

:ipackets: rx_packets
:ibytes: rx_bytes
:imissed: rx_dropped + port.rx_dropped + rx_alloc_fail + rx_pg_alloc_fail
:ierrors: port.rx_crc_errors + port.illegal_bytes + port.rx_length_errors + port.rx_oversize + port.undersize

:Total number of packets: rx_packets + rx_dropped + port.rx_dropped + all kinds of errors

Mellanox
........

:ipackets: rx_packets
:ibytes: rx_bytes
:imissed: rx_dropped + outbound_pci_buffer_overflow + rx_alloc_fail + rx_buff_alloc_err
:ierrors: rx_crc_errors_phy + rx_symbol_err_phy + rx_in_range_len_errors_phy + rx_out_of_range_len_phy + rx_undersize_pkts_phy

Total number of packets seen by the network card = ipackets + imissed + ierrors

Packet drop before AF_Packet = imissed + ierrors / ipackets + imissed + ierrors

Hardware and SoftIRQ statistics
-------------------------------

Read these with the ethtool and keep in mind names may be different between vendors.

I present it here as Intel first and Mellanox second.

::

    ethtool -S <int>

.. table::
   :align: left
   :widths: auto

   ===== ==========
   Intel Mellanox
   ===== ==========

.. table::
   :align: left
   :widths: auto

   ========== ==========
   rx_packets rx_packets
   ========== ==========

The number of successfully received packets (processed by the interface) on the interface. Updated after a successful SKB construction & fetch by NAPI.

.. table::
   :align: left
   :widths: auto

   ======== ========
   rx_bytes rx_bytes
   ======== ========

The number of successfully received bytes (processed by the interface) on the interface. Updated after a successful SKB construction & fetch by NAPI.

.. table::
   :align: left
   :widths: auto

   ================ =================
   rx_pg_alloc_fail rx_buff_alloc_err
   ================ =================

Failed to allocate a page in the DMA area to send packets to. Pages are mostly reused so it is a rare event if a new page has to be allocated


.. table::
   :align: left
   :widths: auto

   ================ =================
   rx_dropped       rx_out_of_buffer
   ================ =================

Number of times receive queue had no software buffers allocated for the adapter's incoming traffic. That simply means there were not enough free buffers to DMA into.

::

    ethtool -g <int>


.. table::
   :align: left
   :widths: auto

   ================ ============================
   port.rx_dropped  outbound_pci_buffer_overflow
   ================ ============================

Received packets from the network that are dropped in the receive packet buffer due to possible lack of bandwidth of the PCIe or the internal data path. If this counter is raising in high rate, it might indicate that the receive traffic rate for a host is larger than the PCIe bus and therefore a congestion occurs. Make sure this card is installed in a PCIe x8 slot. Keep in mind some slots are x8 mechanically but x4 electrically.

.. table::
   :align: left
   :widths: auto

   ================ =================
   rx_alloc_fail
   ================ =================

Failed to construct an SKB from a packet - so also failed to clean the RX ring on time. Intel only.

.. table::
   :align: left
   :widths: auto

   ================== =================
   port.rx_crc_errors rx_crc_errors_phy
   ================== =================

The number of dropped received packets due to FCS (Frame Check Sequence) error on the physical port. If this counter is increased in high rate, check the link quality.
On mellanox also check rx_symbol_error_phy and rx_corrected_bits_phy counters.

.. table::
   :align: left
   :widths: auto

   ================== =======================
   port.rx_oversize   rx_out_of_range_len_phy
   ================== =======================

The number of dropped received packets due to length which exceed MTU size on a physical port.
If this counter is increasing, it implies that the peer connected to the adapter has a larger MTU configured. Using same MTU configuration shall resolve this issue.
For Mellanox, another counter - rx_in_range_len_errors_phy shows the number of received packets dropped due to length/type errors on a physical port.

::

   ip link show <int>

::

   ip link set dev <int> mtu <bytes>

.. table::
   :align: left
   :widths: auto

   ===================== ==========================
   port.rx_length_errors rx_in_range_len_errors_phy
   ===================== ==========================

Number of packets with receive length errors by the port. A length error occurs if an incoming packet length field in the MAC header does not match the packet length.

.. table::
   :align: left
   :widths: auto

   ================== =================
   port.illegal_bytes rx_symbol_err_phy
   ================== =================

The number of received packets dropped due to physical coding errors (symbol errors) on a physical port.

.. table::
   :align: left
   :widths: auto

   ============== =====================
   port.undersize rx_undersize_pkts_phy
   ============== =====================

The number of dropped frames due to length which is shorter than 64 bytes (Mellanox) or 6 bytes with a valid CRC (Intel) on a physical port. If this counter is increasing, it implies that the peer connected to the adapter has a non-standard MTU configured or malformed frame had arrived.

.. table::
   :align: left
   :widths: auto

   ============== ================
   port.fragments rx_fragments_phy
   ============== ================

Number of frames shorter than 64 bytes with invalid CRC

.. table::
   :align: left
   :widths: auto

   ============== ================
   port.fragments rx_jabbers_phy
   ============== ================

Counts the number of received packets that passed address filtering, and are greater than maximum size and have bad CRC (this is slightly different from the Receive Oversize Count register).

Additional softnet counters
---------------------------

Note: values are in hex and there is no header so I made it up using actual variable names from the kernel source. I listed them sequentally, so "processed" is in the first column, "dropped" in the second one and so on.

::

    cat /proc/net/softnet_stat

:processed: number of frames processed. Could be more than the number of frames received, if bonding is used, because it will trigger re-processing.
:dropped: number of frames dropped because there was no room in the per-CPU backlog queue. Not used unless RPS is enabled. Specifically, there is NO per-CPU backlog without RPS.
:squeezed: number of times NAPI ran out of budget or out of time, yet more work could be completed.
:next 5 values: always 0
:cpu_collision: number of times a collision occured while trying to transmit
:received_rps: number of times IPI has been received to process packets as part of the RPS
:flow_limit_count: number of times RFS flow_limit has been reached

Unless RPS is used, the only interesting statistics here is the "dropped" colum. Small increments from time to time are OK, but if it keeps growing it is time to give the NAPI poll more time each time it is woken up to process packets.

Read the current budget with

::

    sysctl net.core.netdev_budget

Increase it x2 and keep monitoring

::

    sysctl -w net.core.netdev_budget=600

Hardware counters for configuration validation
----------------------------------------------

Keep monitoring the following as some should not be growing.

Intel
.....

:port.fdir_match: number of times Intel's Flow Director was able to match a packet. Zero if you have no filters and a growing counters if you have filters and are expecting them to match.
:port.fdir_miss: number of times Intel's Flow Director was not able to match a packet. In the Perfect Filter mode without any filters all traffic will result in fdir_miss as no FD filter is being matched.
:port.fdir_flush_cnt: how many times internal ATR's state has been flushed. ATR should stay disabled at all times and this should be zero.
:port.fdir_atr_match: how many times ATR matched a flow.
:port.fdir_atr_status: 0 is ATR disabled and 1 if enabled.

Mellanox
........
:rx_steer_missed_packets: number of bytes dropped by steering rules

