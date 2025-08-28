//Variables to track states
bool isPlaying = false;
var currentThumbnailURL = "https://raw.githubusercontent.com/ytmdesktop/ytmdesktop/refs/heads/development/src/assets/icons/ytmd.png";
var currentTitle = "N/A";
var currentArtist = "N/A";
var currentAlbum = "null";
bool isSeeking = false;
double videoProgress = 0;
double durationSeconds = 0;
bool shuffle = false;
bool muted = false;
int repeat = 0; //0 None, 1 All, 2 One
int likeStatus = 1; //0 Dislike, 1 Indifferent, 2 Like
int volume = 0;
bool isRequestingVolume = false;
bool isSearchingForServerIP = false;
