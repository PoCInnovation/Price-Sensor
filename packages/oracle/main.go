package main

import (
	"oracle/utils"
	"oracle/watcher"
)

func main() {

	config := utils.NewConfig()

	watcher := watcher.NewWatcher(config)

	watcher.Start()

}
