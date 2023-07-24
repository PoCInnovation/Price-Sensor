package watcher

import (
	"context"
	"fmt"
	"oracle/utils"
	"time"

	"github.com/hasura/go-graphql-client"
)

type Watcher struct {
	config      *utils.Config
	queryClient *graphql.Client
}

func NewWatcher(conf *utils.Config) *Watcher {
	return &Watcher{
		config:      conf,
		queryClient: graphql.NewClient(conf.TheGraphUrl, nil),
	}
}

var first100poolQuery = `query MyQuery {
	pools(first: 100) {
	  price0
	  price1
	  id
	  token0 {
		name
		symbol
		id
	  }
	  token1 {
		name
		symbol
		id
	  }
	}
  }`

var poolQuery = `{
	poolSearch(text: "*", where: {token1: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", token0: "0x682a21d52451bb93e4bda3c557e46e0016d0edb0"}) {
		activeLiquidity
		amount0
		amount1
		price0
		price1
	}
}
`

type SampleQuey struct {
	Lockers []struct {
		Id string
	}
}

func (w *Watcher) Start() {
	fmt.Println("Watcher started")

	var query SampleQuey
	err := w.queryClient.Query(context.Background(), &query, nil)
	if err != nil {
		fmt.Println(err)
	}

	fmt.Println(query)

	for {
		fmt.Println("Watcher is running")

		time.Sleep(1 * time.Second)

	}
}
