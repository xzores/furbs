package audio;

Sound :: struct {

}

Music :: struct {
	looping : bool,
}

load_music_stream :: proc (s : string) -> Music {
	
	return {};
}

play_music_stream :: proc (music : Music) {

}

stop_music_stream :: proc (music : Music) {

}

pause_music_stream :: proc (music : Music) {

}

resume_music_stream :: proc (music : Music) {

}

is_music_stream_playing :: proc (music : Music) -> bool {
	
	return true;
}

set_music_volume :: proc (music : Music, volume : f32) {

}

update_music_stream :: proc (music : Music) {

}