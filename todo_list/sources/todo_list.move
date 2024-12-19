/// Module: todo_list
module todo_list::todo_list;

use std::string::String;
use sui::{clock::Clock, event};

/// List of todos. Can be managed by the owner and shared with others.
public struct TodoList has key, store {
id: UID,
items: vector<String>
}

/// Create a new todo list.
public fun new(ctx: &mut TxContext): TodoList {
let list = TodoList {
id: object::new(ctx),
items: vector[]
};

(list)
}

/// Add a new todo item to the list.
public fun add(list: &mut TodoList, item: String) {
list.items.push_back(item);
}

/// Remove a todo item from the list by index.
public fun remove(list: &mut TodoList, index: u64): String {
list.items.remove(index)
}

/// Delete the list and the capability to manage it.
public fun delete(list: TodoList) {
let TodoList { id, items: _ } = list;
id.delete();
}

/// Get the number of items in the list.
public fun length(list: &TodoList): u64 {
list.items.length()
}

public struct TimeEvent has copy, drop, store {
timestamp_ms: u64,
}

entry fun access(clock: &Clock) {
event::emit(TimeEvent { timestamp_ms: clock.timestamp_ms() });
}

entry fun ts_now(clock: &Clock): u64{
clock.timestamp_ms()
}
