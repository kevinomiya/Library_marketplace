## library_marketplace: Sui Move Library for Book Rental System
This Move library implements a book rental system on the Sui blockchain. It defines structures for libraries, librarians, books, and rented books, along with functions for:

### Library Management:
 - Creating libraries with associated librarian capabilities.
 - Withdrawing funds from the library balance.
### Book Management:
 - Adding books to a library with details like title, author, price, and quantity.
 - Unlisting books from the available inventory.
### Book Rental:
 - Renting books by specifying the library, book ID, quantity, and paying the corresponding amount.
 - Returning rented books.
### Data Access:
 - Retrieving details of libraries, books, and rented books.
 - This library utilizes access control mechanisms to ensure that only authorized users (librarians) can perform specific actions.

### Key Features
- Secure and transparent book rental system on the Sui blockchain.
- Role-based access control with Librarian capabilities.
- Manages book listings, pricing, and availability.
- Tracks book rentals and returns.
- Provides functions for querying library and book details.

### Usage
This library can be integrated into your Sui Move projects to implement a secure and decentralized book rental system. You can use the provided functions to manage libraries, add and remove books, rent and return books, and access relevant data.

