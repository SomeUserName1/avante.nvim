class Customer:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    def check_eligibility(self):
        if self.age > 18:
            return f"{self.name} is eligible."
        else:
            return f"{self.name} is not eligible."

def main():
    # Input: Customer's name and age
    name = input("Enter customer's name: ")
    age = int(input("Enter customer's age: "))

    # Create Customer object
    customer = Customer(name, age)

    # Check eligibility
    print(customer.check_eligibility())

if __name__ == "__main__":
    main()