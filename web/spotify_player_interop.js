var spotifyPlayer;
var localDeviceId; // Stores the device ID of this browser player

// This function is called by the Spotify SDK script once it's loaded
window.onSpotifyWebPlaybackSDKReady = () => {
  console.log("Spotify SDK is ready to be initialized from Dart.");
  // Dart will call initializeSpotifyPlayer when it's ready (e.g., after user login)
};

// Called from Dart to initialize the player
function initializeSpotifyPlayer(token, playerName, onReadyCallback, onStateChangeCallback, onPlayerErrorCallback, onNotReadyCallback) {
  if (!window.Spotify) {
    console.error("Spotify SDK 'Spotify' global object not found.");
    if (onPlayerErrorCallback) onPlayerErrorCallback({ message: "Spotify SDK 'Spotify' global object not found. Ensure SDK script is loaded before interop script." });
    return;
  }

  spotifyPlayer = new Spotify.Player({
    name: playerName, // This name will show up in Spotify Connect devices list
    getOAuthToken: cb => { cb(token); }, // Callback to provide the access token
    volume: 0.5 // Default volume
  });

  // Called when the player is ready and has a device_id
  spotifyPlayer.addListener('ready', ({ device_id }) => {
    console.log('JS: SDK Player Ready with Device ID', device_id);
    localDeviceId = device_id;
    if (onReadyCallback) onReadyCallback(device_id);
  });

  // Called when the player is not ready (e.g., device disconnected)
  spotifyPlayer.addListener('not_ready', ({ device_id }) => {
    console.log('JS: SDK Player Device ID has gone offline', device_id);
    if (onNotReadyCallback) onNotReadyCallback(device_id);
  });

  // Called when the player state changes (track, play/pause, etc.)
  spotifyPlayer.addListener('player_state_changed', state => {
    // console.log('JS: Player state changed', state);
    if (onStateChangeCallback) onStateChangeCallback(state);
  });

  // Error handling
  spotifyPlayer.addListener('initialization_error', ({ message }) => {
    console.error('JS: Failed to initialize SDK Player', message);
    if (onPlayerErrorCallback) onPlayerErrorCallback({ message });
  });
  spotifyPlayer.addListener('authentication_error', ({ message }) => {
    console.error('JS: Failed to authenticate SDK Player', message);
    if (onPlayerErrorCallback) onPlayerErrorCallback({ message });
  });
  spotifyPlayer.addListener('account_error', ({ message }) => {
    // This can happen if the user doesn't have Spotify Premium
    console.error('JS: SDK Player account error', message);
    if (onPlayerErrorCallback) onPlayerErrorCallback({ message });
  });
  spotifyPlayer.addListener('playback_error', ({ message }) => {
    console.error('JS: SDK Player playback error', message);
    if (onPlayerErrorCallback) onPlayerErrorCallback({ message });
  });

  // Connect the player
  spotifyPlayer.connect().then(success => {
    if (success) {
      console.log('JS: The Web Playback SDK successfully connected to Spotify!');
    } else {
      console.error('JS: The Web Playback SDK failed to connect to Spotify.');
      if (onPlayerErrorCallback) onPlayerErrorCallback({ message: "SDK failed to connect." });
    }
  });
}

// Functions to control playback locally if this player is active
function playerTogglePlay() {
  if (spotifyPlayer) spotifyPlayer.togglePlay().catch(e => console.error("Error toggling play:", e));
}
function playerNextTrack() {
  if (spotifyPlayer) spotifyPlayer.nextTrack().catch(e => console.error("Error going to next track:", e));
}
function playerPreviousTrack() {
  if (spotifyPlayer) spotifyPlayer.previousTrack().catch(e => console.error("Error going to previous track:", e));
}

// Function to get the device ID of this player
function getLocalDeviceId() {
  return localDeviceId;
}

// Function to disconnect the Spotify Player
function disconnectSpotifyPlayer() {
    if (spotifyPlayer) {
      spotifyPlayer.disconnect();
      console.log('JS: Spotify Player disconnected.');
      // spotifyPlayer = null; // Optionally nullify to allow re-initialization later if needed by your logic
      // localDeviceId = null;
    }
  }
  
  // Function to get the device ID of this player (keep this if you still use it directly)
  function getLocalDeviceId() {
    return localDeviceId;
  }