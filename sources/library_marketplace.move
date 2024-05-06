module library_markketplace::library_markketplace {

    use sui::sui::SUI;
    use sui::url::{Self, Url};
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::dynamic_field as df;
    use sui::dynamic_object_field as dof;

    const Error_Not_Librarian: u64 = 1;
    const Error_Invalid_WithdrawalAmount: u64 = 2; //  invalid withdrawal amount
    const Error_Invalid_Quantity: u64 = 3; //  invalid quantity
    const Error_Insufficient_Payment: u64 = 4; // insufficient payment
    const Error_Invalid_BookId: u64 = 5; // invalid item id
    const Error_Invalid_Price: u64 = 6; //  invalid price
    const Error_Invalid_Supply: u64 = 7; // invalid supply
    const Error_BookIsNotListed: u64 = 8; // item is not listed
    const Error_Not_Renter: u64 = 9; // not the renter


	public struct Library has key {
		id: UID,
        librarian_cap: ID,
		balance: Balance<SUI>,
        book_count: u64
	}

    public struct LibrarianCapability has key {
        id: UID,
        library: ID,
    }

    public struct Book has key, store {
		id: UID,
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

    public struct Listing has store, copy, drop { id: ID, is_exclusive: bool }

    public struct Item has store, copy, drop { id: ID }

    public struct RentedBook has key {
        id: UID,
        library_id: ID, 
        book_id: u64
    }

    // Implement for create library function
    public fun create_library(recipient: address, ctx: &mut TxContext) {
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
            book_count: 0,
        }); 
    }

    public fun mint( 
        title: vector<u8>, 
        author: vector<u8>,
        description: vector<u8>,
        url: vector<u8>, // display for the book
        price: u64,
        supply: u64,
        category: u8,
        ctx: &mut TxContext,
    ) : Book {

       let id = object::new(ctx);
       let book = Book{
            id: id,
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
        book
    }

   // Function to add Artwork to gallery
    public entry fun list<T: key + store>(
        self: &mut Library,
        cap: &LibrarianCapability,
        item: T,
        price: u64,
    ) {
        assert!(object::id(self) == cap.library, Error_Not_Librarian);
        let id = object::id(&item);
        place_internal(self, item);
        df::add(&mut self.id, Listing { id, is_exclusive: false }, price);
    }

    public fun delist<T: key + store>(
        self: &mut Library, cap: &LibrarianCapability, id: ID
    ) : T {
        assert!(object::id(self) == cap.library, Error_Not_Librarian);
        self.book_count = self.book_count - 1;
        df::remove_if_exists<Listing, u64>(&mut self.id, Listing { id, is_exclusive: false });
        dof::remove(&mut self.id, Item { id })    
    }

    public fun purchase<T: key + store>(
        self: &mut Library, id: ID, payment: Coin<SUI>
    ): T {
        let price = df::remove<Listing, u64>(&mut self.id, Listing { id, is_exclusive: false });
        let inner = dof::remove<Item, T>(&mut self.id, Item { id });

        self.book_count = self.book_count - 1;
        assert!(price == coin::value(&payment), Error_Not_Librarian);
        coin::put(&mut self.balance, payment);
        inner
    }
    // // Implement for return book function
    // public fun return_book(
    //     library: &mut Library,
    //     rented_book: &RentedBook,
    //     renter: address,
    //     ctx: &mut TxContext
    // ) {
    //     assert!(rented_book.library_id == object::uid_to_inner(&library.id), Error_Invalid_BookId);
    //     assert!(rented_book.book_id <= library.books.length(), Error_Invalid_BookId);
    //     assert!(tx_context::sender(ctx) == renter, Error_Not_Renter);

    //     let book = &mut library.books[rented_book.book_id];
    //     book.available = book.available + 1;

    //     if (book.available >= 1) {
    //         vector::borrow_mut(&mut library.books, rented_book.book_id).listed = true;
    //     }
    // }

    // // Implement for withdraw from library function
    // public fun withdraw_from_library(
    //     library: &mut Library,
    //     librarian_cap: &LibrarianCapability,
    //     amount: u64,
    //     recipient: address,
    //     ctx: &mut TxContext
    // ) {
    //     assert!(library.librarian_cap == object::uid_to_inner(&librarian_cap.id), Error_Not_Librarian);
    //     assert!(amount > 0 && amount <= library.balance.value(), Error_Invalid_WithdrawalAmount);

    //     let take_coin = coin::take(&mut library.balance, amount, ctx);
        
    //     transfer::public_transfer(take_coin, recipient);
    // }

    // // withdraw all the balance from the library
    // public fun withdraw_all_from_library(
    //     library: &mut Library,
    //     librarian_cap: &LibrarianCapability,
    //     ctx: &mut TxContext
    // ) : Coin<SUI> {
    //     assert!(library.librarian_cap == object::uid_to_inner(&librarian_cap.id), Error_Not_Librarian);
    //     let amount = library.balance.value();
    //     let take_coin = coin::take(&mut library.balance, amount, ctx);
    //     take_coin
    
    
    // }
    // // getter for the library details
    //     public fun get_library_details(library: &Library) : (&UID, ID, &Balance<SUI>, &vector<Book>, u64) {
    //         (
    //             &library.id, 
    //             library.librarian_cap,
    //             &library.balance, 
    //             &library.books, 
    //             library.book_count
    //         )
    //     }
    
    // // getter for a book details with the book id
    // public fun get_book_details(library: &Library, book_id: u64) : (u64, String, String, String, u64, Url, bool, u8, u64, u64) {
    //     let book = &library.books[book_id];
    //     (
    //         book.id,
    //         book.title,
    //         book.author,
    //         book.description,
    //         book.price,
    //         book.url,
    //         book.listed,
    //         book.category,
    //         book.total_supply,
    //         book.available
    //     )
    // }
    // // getter for the rented book details with the rented book id
    // public fun get_rented_book_details(rented_book: &RentedBook) : (&UID, ID, u64) {
    //     (
    //         &rented_book.id,
    //         rented_book.library_id,
    //         rented_book.book_id
    //     )
    // }

    public fun withdraw(
        self: &mut Library, cap: &LibrarianCapability, amount: u64, ctx: &mut TxContext
    ): Coin<SUI> {
        assert!(object::id(self) == cap.library, Error_Not_Librarian);
        coin::take(&mut self.balance, amount, ctx)
    }

    public fun place_internal<T: key + store>(self: &mut Library, item: T) {
        self.book_count = self.book_count + 1;
        dof::add(&mut self.id, Item { id: object::id(&item) }, item)
    }
}