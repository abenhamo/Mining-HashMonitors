package main

type Addr struct {
	IP   string `json:"ip"`
	Port uint32 `json:"port"`
}
type InterfaceAddr struct {
	Addr string `json:"addr"`
}
type Stat struct {
	Id              string `json:"id"` // mac adress
	Version         string `json:"version"`
	TemperatureStat struct {
		SensorKey   string  `json:"sensorKey"`
		Temperature float64 `json:"sensorTemperature"`
	} `json:"TemperatureStat"`
	InfoStat struct {
		Hostname             string `json:"hostname"`
		Uptime               uint64 `json:"uptime"`
		BootTime             uint64 `json:"bootTime"`
		Procs                uint64 `json:"procs"`           // number of processes
		OS                   string `json:"os"`              // ex: freebsd, linux
		Platform             string `json:"platform"`        // ex: ubuntu, linuxmint
		PlatformFamily       string `json:"platformFamily"`  // ex: debian, rhel
		PlatformVersion      string `json:"platformVersion"` // version of the complete OS
		KernelVersion        string `json:"kernelVersion"`   // version of the OS kernel (if available)
		VirtualizationSystem string `json:"virtualizationSystem"`
		VirtualizationRole   string `json:"virtualizationRole"` // guest or host
		HostID               string `json:"hostid"`             // ex: uuid
	} `json:"InfoStat"`
	AvgStat struct {
		Load1  float64 `json:"load1"`
		Load5  float64 `json:"load5"`
		Load15 float64 `json:"load15"`
	} `json:"AvgStat"`
	VirtualMemoryStat struct {
		// Total amount of RAM on this system
		Total uint64 `json:"total"`

		// RAM available for programs to allocate
		//
		// This value is computed from the kernel specific values.
		Available uint64 `json:"available"`

		// RAM used by programs
		//
		// This value is computed from the kernel specific values.
		Used uint64 `json:"used"`

		// Percentage of RAM used by programs
		//
		// This value is computed from the kernel specific values.
		UsedPercent float64 `json:"usedPercent"`

		// This is the kernel's notion of free memory; RAM chips whose bits nobody
		// cares about the value of right now. For a human consumable number,
		// Available is what you really want.
		Free uint64 `json:"free"`
	} `json:"VirtualMemoryStat"`
	InterfaceStat struct {
		MTU          int             `json:"mtu"`          // maximum transmission unit
		Name         string          `json:"name"`         // e.g., "en0", "lo0", "eth0.100"
		HardwareAddr string          `json:"hardwareaddr"` // IEEE MAC-48, EUI-48 and EUI-64 form
		Flags        []string        `json:"flags"`        // e.g., FlagUp, FlagLoopback, FlagMulticast
		Addrs        []InterfaceAddr `json:"addrs"`
	} `json:"InterfaceStat"`

	Hashrate struct {
		Threads [][]interface{} `json:"threads"`
		Total   []interface{}   `json:"total"`
		Highest float64         `json:"highest"`
	} `json:"hashrate"`
	Results struct {
		DiffCurrent int           `json:"diff_current"`
		SharesGood  int           `json:"shares_good"`
		SharesTotal int           `json:"shares_total"`
		AvgTime     float64       `json:"avg_time"`
		HashesTotal int           `json:"hashes_total"`
		Best        []int         `json:"best"`
		ErrorLog    []interface{} `json:"error_log"`
	} `json:"results"`
	Connection struct {
		Pool     string        `json:"pool"`
		Uptime   int           `json:"uptime"`
		Ping     int           `json:"ping"`
		ErrorLog []interface{} `json:"error_log"`
	} `json:"connection"`
}

type Stats []Stat
