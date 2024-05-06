module library_markketplace::market {

    use sui::sui::SUI;
    use sui::url::{Self, Url};
    use std::string::{String};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::dynamic_field as df;
    use sui::dynamic_object_field as dof;

    const Error_Not_Librarian: u64 = 0;

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
        title: String, 
        author: String,
        description: String,
        url: vector<u8>, // display for the book
        price: u64,
        supply: u64,
        category: u8,
        ctx: &mut TxContext,
    ) : Book {

       let id = object::new(ctx);
       let book = Book{
            id: id,
            title: title,
            author: author,
            description: description,
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

