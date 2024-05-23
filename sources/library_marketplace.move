module library_marketplace::library_marketplace {
    use sui::event;
    use sui::sui::SUI;
    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    const Error_Not_Librarian: u64 = 1;
    const Error_Invalid_WithdrawalAmount: u64 = 2;
    const Error_Invalid_Quantity: u64 = 3;
    const Error_Insufficient_Payment: u64 = 4;
    const Error_Invalid_BookId: u64 = 5;
    const Error_Invalid_Price: u64 = 6;
    const Error_Invalid_Supply: u64 = 7;
    const Error_BookIsNotListed: u64 = 8;
    const Error_Not_Renter: u64 = 9;
    public struct Library has key {
        id: UID,
        librarian_cap: ID,
        balance: Balance<SUI>,
        books: vector<Book>,
        book_count: u64
    }
    public struct LibrarianCapability has key {
        id: UID,
        library: ID,
    }
    public struct Book has store {
        id: u64,
        title: String,
        author: String,
        description: String,
        price: u64,
        url: Url,
        listed: bool,
        category: u8,
        total_supply: u64,
        available: u64
    }
    public struct RentedBook has key {
        id: UID,
        library_id: ID,
        book_id: u64
    }
    public struct LibraryCreated has copy, drop {
        library_id: ID,
        librarian_cap_id: ID,
    }
    public struct BookAdded has copy, drop {
        library_id: ID,
        book: u64,
    }
    public struct BookRented has copy, drop {
        library_id: ID,
        book_id: u64,
        quantity: u64,
        renter: address,
    }
    public struct BookReturned has copy, drop {
        library_id: ID,
        book_id: u64,
        quantity: u64,
        renter: address,
    }
    public struct BookUnlisted has copy, drop {
        library_id: ID,
        book_id: u64
    }
    public struct LibraryWithdrawal has copy, drop {
        library_id: ID,
        amount: u64,
        recipient: address
    }
    // Create a new library
    public entry fun create_library(recipient: address, ctx: &mut TxContext) {
        let library_uid = object::new(ctx);
        let librarian_cap_uid = object::new(ctx);
        let library_id = object::uid_to_inner(&library_uid);
        let librarian_cap_id = object::uid_to_inner(&librarian_cap_uid);
        transfer::transfer(LibrarianCapability {
            id: librarian_cap_uid,
            library: library_id
        }, recipient);
        transfer::share_object(Library {
            id: library_uid,
            librarian_cap: librarian_cap_id,
            balance: balance::zero<SUI>(),
            books: vector::empty(),
            book_count: 0,
        });
        event::emit(LibraryCreated{
            library_id,
            librarian_cap_id
        });
    }
    // Add a new book to the library
    public entry fun add_book(
        library: &mut Library,
        librarian_cap: &LibrarianCapability,
        title: vector<u8>,
        author: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        price: u64,
        supply: u64,
        category: u8
    ) {
        assert!(library.librarian_cap == object::uid_to_inner(&librarian_cap.id), Error_Not_Librarian);
        assert!(price > 0, Error_Invalid_Price);
        assert!(supply > 0, Error_Invalid_Supply);
        let book_id = library.books.length();
        let book = Book {
            id: book_id,
            title: string::utf8(title),
            author: string::utf8(author),
            description: string::utf8(description),
            price: price,
            url: url::new_unsafe_from_bytes(url),
            listed: true,
            category: category,
            total_supply: supply,
            available: supply,
        };
        library.books.push_back(book);
        library.book_count = library.book_count + 1;
        event::emit(BookAdded {
            library_id: librarian_cap.library,
            book: book_id
        });
    }
    // Unlist a book from the library
    public entry fun unlist_book(
        library: &mut Library,
        librarian_cap: &LibrarianCapability,
        book_id: u64
    ) {
        assert!(library.librarian_cap == object::uid_to_inner(&librarian_cap.id), Error_Not_Librarian);
        assert!(book_id < library.books.length(), Error_Invalid_BookId);
        let book = &mut library.books[book_id];
        book.listed = false;
        event::emit(BookUnlisted {
            library_id: object::uid_to_inner(&library.id),
            book_id: book_id
        });
    }
    // Rent a book from the library
    public entry fun rent_book(
        library: &mut Library,
        book_id: u64,
        quantity: u64,
        renter: address,
        payment_coin: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        assert!(book_id < library.books.length(), Error_Invalid_BookId);
        assert!(quantity > 0, Error_Invalid_Quantity);
        let book = &mut library.books[book_id];
        assert!(book.available >= quantity, Error_Invalid_Quantity);
        assert!(book.listed, Error_BookIsNotListed);
        let total_price = book.price * quantity;
        assert!(coin::value(&payment_coin) >= total_price, Error_Insufficient_Payment);
        book.available = book.available - quantity;
        let paid = coin::split(&mut payment_coin, total_price, ctx);
        coin::put(&mut library.balance, paid);
        for _ in 0..quantity {
            let rented_book_uid = object::new(ctx);
            transfer::transfer(RentedBook {
                id: rented_book_uid,
                library_id: object::uid_to_inner(&library.id),
                book_id: book_id
            }, renter);
        }
        event::emit(BookRented {
            library_id: object::uid_to_inner(&library.id),
            book_id: book_id,
            quantity: quantity,
            renter: renter,
        });
        if book.available == 0 {
            unlist_book(library, &librarian_cap, book_id);
        }
    }
    // Return a rented book to the library
    public entry fun return_book(
        library: &mut Library,
        rented_book: RentedBook,
        renter: address,
        ctx: &mut TxContext
    ) {
        assert!(rented_book.library_id == object::uid_to_inner(&library.id), Error_Invalid_BookId);
        assert!(rented_book.book_id < library.books.length(), Error_Invalid_BookId);
        assert!(tx_context::sender(ctx) == renter, Error_Not_Renter);
        let book = &mut library.books[rented_book.book_id];
        book.available = book.available + 1;
        event::emit(BookReturned {
            library_id: object::uid_to_inner(&library.id),
            book_id: rented_book.book_id,
            quantity: 1,
            renter: renter,
        });
        if book.available >= 1 {
            vector::borrow_mut(&mut library.books, rented_book.book_id).listed = true;
        }
    }
    // Withdraw funds from the library
    public entry fun withdraw_from_library(
        library: &mut Library,
        librarian_cap: &LibrarianCapability,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(library.librarian_cap == object::uid_to_inner(&librarian_cap.id), Error_Not_Librarian);
        assert!(amount > 0 && amount <= balance::value(&library.balance), Error_Invalid_WithdrawalAmount);
        let take_coin = balance::take(&mut library.balance, amount, ctx);
        transfer::public_transfer(take_coin, recipient);
        event::emit(LibraryWithdrawal {
            library_id: object::uid_to_inner(&library.id),
            amount: amount,
            recipient: recipient
        });
    }
    // Withdraw all funds from the library
    public entry fun withdraw_all_from_library(
        library: &mut Library,
        librarian_cap: &LibrarianCapability,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(library.librarian_cap == object::uid_to_inner(&librarian_cap.id), Error_Not_Librarian);
        let amount = balance::value(&library.balance);
        let take_coin = balance::take(&mut library.balance, amount, ctx);
        transfer::public_transfer(take_coin, recipient);
        event::emit(LibraryWithdrawal {
            library_id: object::uid_to_inner(&library.id),
            amount: amount,
            recipient: recipient
        });
    }
    // Get library details
    public fun get_library_details(library: &Library) : (&UID, ID, &Balance<SUI>, &vector<Book>, u64) {
        (
            &library.id,
            library.librarian_cap,
            &library.balance,
            &library.books,
            library.book_count
        )
    }
    // Get book details by book ID
    public fun get_book_details(library: &Library, book_id: u64) : (u64, String, String, String, u64, Url, bool, u8, u64, u64) {
        assert!(book_id < library.books.length(), Error_Invalid_BookId);
        let book = &library.books[book_id];
        (
            book.id,
            book.title,
            book.author,
            book.description,
            book.price,
            book.url,
            book.listed,
            book.category,
            book.total_supply,
            book.available
        )
    }
    // Get rented book details by rented book ID
    public fun get_rented_book_details(rented_book: &RentedBook) : (&UID, ID, u64) {
        (
            &rented_book.id,
            rented_book.library_id,
            rented_book.book_id
        )
    }
    // Update the renter of the rented book
    public fun update_rented_book_renter(rented_book: &mut BookRented, renter: address) {
        rented_book.renter = renter;
    }
}