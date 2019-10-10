#!/bin/bash

# Code from https://gist.github.com/SaveTheRbtz/172b2e2eb3cbd96b598d
# https://www.redhat.com/archives/rhl-list/2007-September/msg03735.html
# https://github.com/hiboma/hiboma/blob/master/kernel/net/softnet_stat.md

cmd="${0##*/}"

usage() {
cat >&2 <<EOI
usage: $cmd [ -h ]

Output column definitions:
      cpu  # of the cpu 

    total  # of packets (not including netpoll) received by the interrupt handler
             There might be some double counting going on:
                net/core/dev.c:1643: __get_cpu_var(netdev_rx_stat).total++;
                net/core/dev.c:1836: __get_cpu_var(netdev_rx_stat).total++;
             I think the intention was that these were originally on separate
             receive paths ... 

  dropped  # of packets that were dropped because netdev_max_backlog was exceeded

 squeezed  # of times ksoftirq ran out of netdev_budget or time slice with work
             remaining

collision  # of times that two cpus collided trying to get the device queue lock.

EOI
	exit 1
}



softnet_stats_header() {
	printf "%3s %10s %10s %10s %10s\n" cpu total dropped squeezed collision
}

softnet_stats_format() {
	printf "%3u %10lu %10lu %10lu %10lu\n" "$1" "0x$2" "0x$3" "0x$4" "0x$5"
}


getopts h flag && usage

cpu=0
softnet_stats_header
while read total dropped squeezed j1 j2 j3 j4 j5 collision
do
	softnet_stats_format $((cpu++)) "$total" "$dropped" "$squeezed" "$collision"
done < /proc/net/softnet_stat
