---------------------------------
--- @file dpdkc.lua
--- @brief DPDKc ...
--- @todo TODO docu
---------------------------------

--- low-level dpdk wrapper
local ffi = require "ffi"

-- structs
ffi.cdef[[
	// core management
	enum rte_lcore_state_t {
		WAIT, RUNNING, FINISHED
	};

	

	// packets/mbufs
	
	struct mempool {
	}; // dummy struct, only needed to associate it with a metatable

	typedef void    *MARKER[0];
	typedef void    *MARKER_CACHE_ALIGNED[0] __attribute__((aligned(64)));
	typedef uint8_t  MARKER8[0];
	typedef uint64_t MARKER64[0];
	
	struct rte_mbuf;
	union rte_ipsec {
		uint32_t data;
		//struct {
		//	uint16_t sa_idx:10;
		//	uint16_t esp_len:9;
		//	uint8_t type:1;
		//	uint8_t mode:1;
		//	uint16_t unused:11; /**< These 11 bits are unused. */
		//} sec;
	};

	struct rte_mbuf {
		MARKER cacheline0;

		void *buf_addr;           /**< Virtual address of segment buffer. */
		void *buf_physaddr; /**< Physical address of segment buffer. */

		uint16_t buf_len;         /**< Length of segment buffer. */

		/* next 6 bytes are initialised on RX descriptor rearm */
		MARKER8 rearm_data;
		uint16_t data_off;

		uint16_t refcnt;
		uint8_t nb_segs;          /**< Number of segments. */
		uint8_t port;             /**< Input port. */

		uint64_t ol_flags;        /**< Offload features. */
		/* remaining bytes are set on RX when pulling packet from descriptor */
		MARKER rx_descriptor_fields1;

		/*
		* The packet type, which is the combination of outer/inner L2, L3, L4
		* and tunnel types.
		 */
		uint32_t packet_type; /**< L2/L3/L4 and tunnel information. */

		uint32_t pkt_len;         /**< Total pkt len: sum of all segments. */
		uint16_t data_len;        /**< Amount of data in segment buffer. */
		uint16_t vlan_tci;        /**< VLAN Tag Control Identifier (CPU order) */

		union {
			uint32_t rss;     /**< RSS hash result if RSS enabled */
			struct {
				union {
					struct {
						uint16_t hash;
						uint16_t id;
					};
					uint32_t lo;
					/**< Second 4 flexible bytes */
				};
				uint32_t hi;
				/**< First 4 flexible bytes or FD ID, dependent on
			     PKT_RX_FDIR_* flag in ol_flags. */
			} fdir;           /**< Filter identifier if FDIR enabled */
			struct {
				uint32_t lo;
				uint32_t hi;
			} sched;          /**< Hierarchical scheduler */
			uint32_t usr;	  /**< User defined tags. See rte_distributor_process() */
		} hash;                   /**< hash information */

		uint32_t seqn; /**< Sequence number. See also rte_reorder_insert() */

		uint16_t vlan_tci_outer;  /**< Outer VLAN Tag Control Identifier (CPU order) */

		/* second cache line - fields only used in slow path or on TX */
		MARKER_CACHE_ALIGNED cacheline1;

		uint64_t udata64;

		struct rte_mempool *pool; /**< Pool from which mbuf was allocated. */
		struct rte_mbuf *next;    /**< Next segment of scattered packet. */

		/* fields to support TX offloads */
		uint64_t tx_offload;

		/** Size of the application private data. In case of an indirect
		 * mbuf, it stores the direct mbuf private data size. */
		uint16_t priv_size;

		/** Timesync flags for use with IEEE1588. */
		uint16_t timesync;

		/* Chain of off-load operations to perform on mbuf */
		struct rte_mbuf_offload *offload_ops;
	};

	// device status/info
	struct rte_eth_link {
		uint16_t link_speed;
		uint16_t link_duplex;
		uint8_t link_status: 1;
	} __attribute__((aligned(8)));

	struct rte_fdir_filter {
		uint16_t flex_bytes;
		uint16_t vlan_id;
		uint16_t port_src;
		uint16_t port_dst;
		union {
			uint32_t ipv4_addr;
			uint32_t ipv6_addr[4];
		} ip_src;
		union {
			uint32_t ipv4_addr;
			uint32_t ipv6_addr[4];
		} ip_dst;
		int l4type;
		int iptype;
	};
	enum rte_l4type {
		RTE_FDIR_L4TYPE_NONE = 0,       /**< None. */
		RTE_FDIR_L4TYPE_UDP,            /**< UDP. */
		RTE_FDIR_L4TYPE_TCP,            /**< TCP. */
		RTE_FDIR_L4TYPE_SCTP,           /**< SCTP. */
	};


	struct rte_fdir_masks {
		uint8_t only_ip_flow;
		uint8_t vlan_id;
		uint8_t vlan_prio;
		uint8_t flexbytes;
		uint8_t set_ipv6_mask;
		uint8_t comp_ipv6_dst;
		uint32_t dst_ipv4_mask;
		uint32_t src_ipv4_mask;
		uint16_t dst_ipv6_mask;
		uint16_t src_ipv6_mask;
		uint16_t src_port_mask;
		uint16_t dst_port_mask;
	};



	struct phobos_device_config {
		uint32_t port;
		struct mempool** mempools;
		uint16_t rx_queues;
		uint16_t tx_queues;
		uint16_t rx_descs;
		uint16_t tx_descs;
		bool drop_enable;
		bool enable_rss;
		bool disable_offloads;
		bool strip_vlan;
		uint32_t rss_mask;
	};
]]

-- dpdk functions and wrappers
ffi.cdef[[
	// eal init
	int rte_eal_init(int argc, const char* argv[]); 
	
	// cpu core management
	int rte_eal_get_lcore_state(int core);
	enum rte_lcore_state_t rte_eal_get_lcore_state(unsigned int slave_id);
	int rte_eal_wait_lcore(int core);
	uint32_t rte_lcore_to_socket_id_export(uint32_t lcore_id);
	uint32_t get_current_core();
	uint32_t get_current_socket();

	// memory
	struct mempool* init_mem(uint32_t nb_mbuf, uint32_t sock, uint32_t mbuf_size);
	struct rte_mbuf* alloc_mbuf(struct mempool* mp);
	void alloc_mbufs(struct mempool* mp, struct rte_mbuf* bufs[], uint32_t len, uint16_t pkt_len);
	void rte_pktmbuf_free_export(struct rte_mbuf* m);
	uint16_t rte_mbuf_refcnt_read_export(struct rte_mbuf* m);
	uint16_t rte_mbuf_refcnt_update_export(struct rte_mbuf* m, int16_t value);
	void init_mempool_ops();

	// devices
	void register_pmd_drivers();
	int rte_eal_pci_probe();
	int rte_eth_dev_count();
	uint64_t dpdk_get_mac_addr(int port, char* buf);
	void rte_eth_link_get(uint8_t port, struct rte_eth_link* link);
	void rte_eth_link_get_nowait(uint8_t port, struct rte_eth_link* link);
	int dpdk_configure_device(struct phobos_device_config*);
	void get_mac_addr(int port, char* buf);
	uint32_t dpdk_get_pci_id(uint8_t port);
	uint32_t read_reg32(uint8_t port, uint32_t reg);
	uint64_t read_reg64(uint8_t port, uint32_t reg);
	void write_reg32(uint8_t port, uint32_t reg, uint32_t val);
	void write_reg64(uint8_t port, uint32_t reg, uint64_t val);
	void rte_eth_promiscuous_enable(uint8_t port);
	void rte_eth_promiscuous_disable(uint8_t port);
	uint8_t dpdk_get_socket(uint8_t port);
	void* dpdk_get_eth_dev(int port);
	void* dpdk_get_i40e_dev(int port);
	int dpdk_get_i40e_vsi_seid(int port);
	uint8_t dpdk_get_pci_function(uint8_t port);
	int dpdk_get_max_ports();
	const char* dpdk_get_driver_name(int port);
	int rte_eth_dev_mac_addr_add(uint8_t port, void* mac, uint32_t pool);
	int rte_eth_dev_mac_addr_remove(uint8_t port, void* mac);
	void rte_eth_macaddr_get(uint8_t port_id, struct ether_addr* mac_addr);
	int rte_eth_set_queue_rate_limit(uint8_t port_id, uint16_t queue_idx, uint16_t tx_rate);

	// rx & tx
	uint16_t rte_eth_rx_burst_export(uint8_t port_id, uint16_t queue_id, struct rte_mbuf** rx_pkts, uint16_t nb_pkts);
	uint16_t rte_eth_tx_burst_export(uint8_t port_id, uint16_t queue_id, struct rte_mbuf** tx_pkts, uint16_t nb_pkts);
	int rte_eth_dev_tx_queue_start(uint8_t port_id, uint16_t rx_queue_id);
	int rte_eth_dev_tx_queue_stop(uint8_t port_id, uint16_t rx_queue_id);
	void dpdk_send_all_packets(uint8_t port_id, uint16_t queue_id, struct rte_mbuf** pkts, uint16_t num_pkts);


	// stats
	uint32_t dpdk_get_rte_queue_stat_cntrs_num();
	int rte_eth_stats_get(uint8_t port_id, void* stats);
	
	// checksum offloading
	void calc_ipv4_pseudo_header_checksum(void* data, int offset);
	void calc_ipv4_pseudo_header_checksums(struct rte_mbuf** pkts, uint16_t num_pkts, int offset);
	void calc_ipv6_pseudo_header_checksum(void* data, int offset);
	void calc_ipv6_pseudo_header_checksums(struct rte_mbuf** pkts, uint16_t num_pkts, int offset);

	// timers
	void rte_delay_ms_export(uint32_t ms);
	void rte_delay_us_export(uint32_t us);
	uint64_t rte_rdtsc();
	uint64_t rte_get_tsc_hz();

	// lifecycle
	uint8_t is_running(uint32_t extra_time);
	void set_runtime(uint32_t ms);

	// timestamping
	uint16_t dpdk_receive_with_timestamps_software(uint8_t port_id, uint16_t queue_id, struct rte_mbuf** rx_pkts, uint16_t nb_pkts);

	// statistics
	void rte_eth_stats_get(uint8_t port, struct rte_eth_stats* stats);
]]

return ffi.C

