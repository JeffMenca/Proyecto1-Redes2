data_file = """
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy accept;
    }
    chain forward {
        type filter hook forward priority filter; policy accept;
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}

table ip loadbalance {
    chain prerouting {
        type filter hook prerouting priority 0; policy accept;
        ip saddr $PRIVATE_NETWORK ip daddr != $PRIVATE_NETWORK meta mark set numgen random mod 2
    }

    chain output {
        type route hook output priority 0; policy accept;
        meta mark 0 oif "$INTERFACE_ISP1"
        meta mark 1 oif "$INTERFACE_ISP2"
    }
}
"""
