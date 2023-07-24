package utils

import (
	"log"

	"github.com/joho/godotenv"
)

type Config struct {
	FactoryAddress string
	TheGraphUrl    string
}

func init() {
	if err := godotenv.Load(".env"); err != nil {
		log.Fatal("Error loading .env file: ", err.Error())
	}
}

func NewConfig() *Config {
	return &Config{
		FactoryAddress: Env("FACTORY_ADDRESS").IsRequired().Get(),
		TheGraphUrl:    Env("THE_GRAPH_URL").IsRequired().Get(),
	}
}
