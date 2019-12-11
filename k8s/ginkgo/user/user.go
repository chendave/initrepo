package user

//import "fmt"

type User struct {
	FirstName string
	LastName  string
}

func (u User) FullName() string {
	if u.FirstName != "" && u.LastName != "" {
		return u.FirstName + " " + u.LastName
	} else if u.FirstName != "" {
		return u.FirstName
	} else {
		return u.LastName
	}
}

func New() (*User, error) {
	return &User{FirstName: "", LastName: ""}, nil
}
