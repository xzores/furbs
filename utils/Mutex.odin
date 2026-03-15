package utils;

import "core:fmt"
import "core:sync"
import "base:runtime"

TRACY_ENABLE 	:: #config(ODIN_DEBUG, false);
LOCK_DEBUG 		:: #config(ODIN_DEBUG, true);

import "../tracy"

when LOCK_DEBUG || TRACY_ENABLE {

	Mutex :: struct {
		locked_loc : runtime.Source_Code_Location,
		locking_thread : int,
		location_mutex : sync.Mutex,
		using _ : sync.Mutex,
	}

	RW_Mutex :: struct {
		locked_loc : runtime.Source_Code_Location,
		locking_thread : int,
		location_mutex : sync.Mutex,
		using _ : sync.RW_Mutex,
	}

	////////////////////////////////////////////////////////////////////

	lock :: proc(mutex : ^Mutex, loc := #caller_location) {
		
		assert(mutex != nil);

		l := sync.try_lock(mutex);
		if !l {
			sync.lock(&mutex.location_mutex);
			tracy.Message(fmt.tprintf("Lock collision between %v and %v", loc, mutex.locked_loc));
			fmt.assertf(mutex.locking_thread != sync.current_thread_id(), "Thread already locked this mutex at %v", mutex.locked_loc, loc);
			sync.unlock(&mutex.location_mutex);
			sync.lock(mutex);
		}
		sync.lock(&mutex.location_mutex);
		mutex.locked_loc = loc;
		mutex.locking_thread = sync.current_thread_id();
		sync.unlock(&mutex.location_mutex);
	}

	unlock :: proc(mutex : ^Mutex, loc := #caller_location) {

		sync.lock(&mutex.location_mutex);
		mutex.locked_loc = {};
		mutex.locking_thread = 0;
		sync.unlock(&mutex.location_mutex);
		sync.unlock(mutex);
	}
	
	try_lock :: proc(mutex : ^Mutex, loc := #caller_location) -> bool {
		
		assert(mutex != nil);

		sync.lock(&mutex.location_mutex);
		fmt.assertf(mutex.locking_thread != sync.current_thread_id(), "Thread already locked this mutex at %v", mutex.locked_loc, loc);
		sync.unlock(&mutex.location_mutex);
		
		l := sync.try_lock(mutex);
		if l {
			sync.lock(&mutex.location_mutex);
			mutex.locked_loc = loc;
			mutex.locking_thread = sync.current_thread_id();
			sync.unlock(&mutex.location_mutex);
		}

		return l;
	}

	/////////////////

	lock_write :: proc(mutex : ^RW_Mutex, loc := #caller_location) {
		//tracy.Zone();

		assert(mutex != nil);
		
		l := sync.rw_mutex_try_lock(mutex);
		if !l {
			sync.lock(&mutex.location_mutex);
			tracy.Message(fmt.tprintf("Lock (write) collision between %v and %v", loc, mutex.locked_loc));
			fmt.assertf(mutex.locking_thread != sync.current_thread_id(), "Thread already locked this mutex (write) at %v", mutex.locked_loc, loc)
			sync.unlock(&mutex.location_mutex);
			sync.rw_mutex_lock(mutex);
		}
		sync.lock(&mutex.location_mutex);
		mutex.locked_loc = loc;
		mutex.locking_thread = sync.current_thread_id();
		sync.unlock(&mutex.location_mutex);
	}

	unlock_write :: proc(mutex : ^RW_Mutex, loc := #caller_location) {
		//tracy.Zone();

		sync.lock(&mutex.location_mutex);
		mutex.locked_loc = {};
		mutex.locking_thread = 0;
		sync.unlock(&mutex.location_mutex);
		sync.rw_mutex_unlock(mutex);
	}

	////

	lock_read :: proc(mutex : ^RW_Mutex, loc := #caller_location) {
		//tracy.Zone();
		
		assert(mutex != nil);

		l := sync.rw_mutex_try_shared_lock(mutex);
		if !l {
			sync.lock(&mutex.location_mutex);
			tracy.Message(fmt.tprintf("Lock (read) collision between %v and %v", loc, mutex.locked_loc));
			fmt.assertf(mutex.locking_thread != sync.current_thread_id(), "Thread already locked this mutex (read) at %v", mutex.locked_loc, loc)
			sync.unlock(&mutex.location_mutex);
			sync.rw_mutex_shared_lock(mutex);
		}
		sync.lock(&mutex.location_mutex);
		mutex.locked_loc = loc;
		mutex.locking_thread = sync.current_thread_id();
		sync.unlock(&mutex.location_mutex);
	}

	unlock_read :: proc(mutex : ^RW_Mutex, loc := #caller_location) {
		//tracy.Zone();

		sync.lock(&mutex.location_mutex);
		mutex.locked_loc = {};
		mutex.locking_thread = 0;
		sync.unlock(&mutex.location_mutex);
		sync.rw_mutex_shared_unlock(mutex);
	}

	/////////////////
}
else {
	Mutex :: sync.Mutex;
	RW_Mutex :: sync.RW_Mutex;
	
	lock :: sync.lock;
	unlock :: sync.unlock;
	try_lock :: sync.try_lock;

	lock_write :: sync.rw_mutex_lock;
	unlock_write :: sync.rw_mutex_unlock;
	
	lock_read :: sync.rw_mutex_shared_lock;
	unlock_read :: sync.rw_mutex_shared_unlock;
}
