package main

import "net/http"

type Route struct {
	Name        string
	Method      string
	Pattern     string
	HandlerFunc http.HandlerFunc
}

type Routes []Route

var routes = Routes{
	Route{
		"Index",
		"GET",
		"/",
		Index,
	},
	Route{
		"StatIndex",
		"GET",
		"/stats",
		StatIndex,
	},
	Route{
		"StatShow",
		"GET",
		"/stats/{statId}",
		StatShow,
	},
	Route{
		"StatCreate",
		"POST",
		"/stats",
		StatCreate,
	},
}
