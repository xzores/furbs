package utils;

import "core:fmt"
import "core:sync"
import "core:runtime"

when LOCK_DEBUG || TRACY_ENABLE {

	Mutex :: struct #no_copy {
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

	lock :: proc(using mutex : ^Mutex, loc := #caller_location) {
		
		assert(mutex != nil);

		l := sync.try_lock(mutex);
		if !l {
			sync.lock(&location_mutex);
			tracy.Message(fmt.tprintf("Lock collision between %v and %v", loc, locked_loc));
			fmt.assertf(locking_thread != sync.current_thread_id(), "Thread already locked this mutex at %v", locked_loc, loc);
			sync.unlock(&location_mutex);
			sync.lock(mutex);
		}
		sync.lock(&location_mutex);
		locked_loc = loc;
		locking_thread = sync.current_thread_id();
		sync.unlock(&location_mutex);
	}

	unlock :: proc(using mutex : ^Mutex, loc := #caller_location) {

		sync.lock(&location_mutex);
		locked_loc = {};
		locking_thread = 0;
		sync.unlock(&location_mutex);
		sync.unlock(mutex);
	}
	
	try_lock :: proc(using mutex : ^Mutex, loc := #caller_location) -> bool {
		
		assert(mutex != nil);

		sync.lock(&location_mutex);
		fmt.assertf(locking_thread != sync.current_thread_id(), "Thread already locked this mutex at %v", locked_loc, loc);
		sync.unlock(&location_mutex);
		
		l := sync.try_lock(mutex);
		if l {
			sync.lock(&location_mutex);
			locked_loc = loc;
			locking_thread = sync.current_thread_id();
			sync.unlock(&location_mutex);
		}

		return l;
	}

	/////////////////

	lock_write :: proc(using mutex : ^RW_Mutex, loc := #caller_location) {
		//tracy.Zone();

		assert(mutex != nil);
		
		l := sync.rw_mutex_try_lock(mutex);
		if !l {
			sync.lock(&location_mutex);
			tracy.Message(fmt.tprintf("Lock (write) collision between %v and %v", loc, locked_loc));
			fmt.assertf(locking_thread != sync.current_thread_id(), "Thread already locked this mutex (write) at %v", locked_loc, loc)
			sync.unlock(&location_mutex);
			sync.rw_mutex_lock(mutex);
		}
		sync.lock(&location_mutex);
		locked_loc = loc;
		locking_thread = sync.current_thread_id();
		sync.unlock(&location_mutex);
	}

	unlock_write :: proc(using mutex : ^RW_Mutex, loc := #caller_location) {
		//tracy.Zone();

		sync.lock(&location_mutex);
		locked_loc = {};
		locking_thread = 0;
		sync.unlock(&location_mutex);
		sync.rw_mutex_unlock(mutex);
	}

	////

	lock_read :: proc(using mutex : ^RW_Mutex, loc := #caller_location) {
		//tracy.Zone();
		
		assert(mutex != nil);

		l := sync.rw_mutex_try_shared_lock(mutex);
		if !l {
			sync.lock(&location_mutex);
			tracy.Message(fmt.tprintf("Lock (read) collision between %v and %v", loc, locked_loc));
			fmt.assertf(locking_thread != sync.current_thread_id(), "Thread already locked this mutex (read) at %v", locked_loc, loc)
			sync.unlock(&location_mutex);
			sync.rw_mutex_shared_lock(mutex);
		}
		sync.lock(&location_mutex);
		locked_loc = loc;
		locking_thread = sync.current_thread_id();
		sync.unlock(&location_mutex);
	}

	unlock_read :: proc(using mutex : ^RW_Mutex, loc := #caller_location) {
		//tracy.Zone();

		sync.lock(&location_mutex);
		locked_loc = {};
		locking_thread = 0;
		sync.unlock(&location_mutex);
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