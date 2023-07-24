package utils

import (
	"log"

	"github.com/joho/godotenv"
)

type config struct {
	FactoryAddress string
}

var Config *config

func init() {
	if err := godotenv.Load(".env"); err != nil {
		log.Fatal("Error loading .env file: ", err.Error())
	}

	Config = &config{
		FactoryAddress: Env("FACTORY_ADDRESS").IsRequired().Get(),
	}
}
