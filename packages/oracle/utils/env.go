package utils

import (
	"log"
	"os"
)

type EnvGetter struct {
	key      string
	required bool
	fallback string
}

func Env(key string) *EnvGetter {
	return &EnvGetter{key, false, ""}
}

func (e *EnvGetter) IsRequired() *EnvGetter {
	e.required = true
	return e
}

func (e *EnvGetter) WithFallback(fallback string) *EnvGetter {
	e.fallback = fallback
	return e
}

func (e *EnvGetter) Get() string {
	value, exists := os.LookupEnv(e.key)
	if !exists {
		if e.required {
			log.Fatalf("Environment variable %s is required", e.key)
		}
		return e.fallback
	}
	return value
}
