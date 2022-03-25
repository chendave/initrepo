package books

import "fmt"

const (
	FIFTEEN = 15
	THREE   = 3
	FIVE    = 5
)

func IsDivisibleBy(number, divisor int) bool {
	return number%divisor == 0
}

func Says(number int) string {
	switch {
	case IsDivisibleBy(number, FIFTEEN):
		return "fizzbuzz"
	case IsDivisibleBy(number, THREE):
		return "fizz"
	case IsDivisibleBy(number, FIVE):
		return "buzz"
	default:
		return fmt.Sprintf("%d", number)
	}
}
