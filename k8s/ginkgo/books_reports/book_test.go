package books_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/books"
)

var _ = Describe("Book", func() {
        Context("knows when a number", func() {
                It("is divisible by 3", func() {
                        Expect(books.IsDivisibleBy(3, 3)).To(BeTrue())
                })

                It("is NOT divisible by 3", func() {
                        Expect(books.IsDivisibleBy(1, 3)).To(BeFalse())
                })

                It("is divisible by 5", func() {
                        Expect(books.IsDivisibleBy(5, 5)).To(BeTrue())
                })

                It("is NOT divisible by 5", func() {
                        Expect(books.IsDivisibleBy(1, 5)).To(BeFalse())
                })

                It("is divisible by 3 and  5", func() {
                        Expect(books.IsDivisibleBy(15, 15)).To(BeTrue())
                })

                It("is NOT divisible by 3 or 5", func() {
                        Expect(books.IsDivisibleBy(1, 15)).To(BeFalse())
                })
        })
})
