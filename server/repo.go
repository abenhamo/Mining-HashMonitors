package main

import "fmt"

var currentId int

var stats Stats

func RepoFindStat(id string) Stat {
	for _, t := range stats {
		if t.InterfaceStat.HardwareAddr == id {
			return t
		}
	}
	// return empty Stat if not found
	return Stat{}
}

func RepoCreateStat(newStat Stat) Stat {
	for _, t := range stats {
		if t.InterfaceStat.HardwareAddr == newStat.InterfaceStat.HardwareAddr {
			t = newStat
			return newStat
		}
	}
	//currentId += 1
	//newStat.Id = currentId
	stats = append(stats, newStat)
	return newStat
}

func RepoDestroyStat(id string) error {
	for i, t := range stats {
		if t.InterfaceStat.HardwareAddr == id {
			stats = append(stats[:i], stats[i+1:]...)
			return nil
		}
	}
	return fmt.Errorf("Could not find Stat with id of %d to delete", id)
}
