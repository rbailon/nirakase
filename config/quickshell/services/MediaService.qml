pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root

    // Reference to the active Mpris player
    property var activePlayer: null

    // Reactive status flags
    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying : false
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string trackAlbum: activePlayer ? (activePlayer.trackAlbum || "") : ""
    readonly property string trackArtUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property string identity: activePlayer ? (activePlayer.identity || "") : ""
    property int positionTick: 0
    Timer {
        interval: 500
        running: root.isPlaying
        repeat: true
        onTriggered: root.positionTick++
    }

    readonly property double position: {
        var _ = positionTick;
        return activePlayer ? (activePlayer.position || 0) : 0;
    }
    readonly property double length: activePlayer ? (activePlayer.length || 0) : 0
    readonly property bool positionSupported: activePlayer ? activePlayer.positionSupported : false
    readonly property bool lengthSupported: activePlayer ? activePlayer.lengthSupported : false

    // Capability flags
    readonly property bool canControl: activePlayer ? activePlayer.canControl : false
    readonly property bool canPlay: activePlayer ? activePlayer.canPlay : false
    readonly property bool canPause: activePlayer ? activePlayer.canPause : false
    readonly property bool canSeek: activePlayer ? activePlayer.canSeek : false
    readonly property bool canGoNext: activePlayer ? activePlayer.canGoNext : false
    readonly property bool canGoPrevious: activePlayer ? activePlayer.canGoPrevious : false

    function formatTime(seconds) {
        if (!seconds || isNaN(seconds) || seconds < 0) return "0:00";
        var s = Math.floor(seconds);
        var m = Math.floor(s / 60);
        var remSec = s % 60;
        var h = Math.floor(m / 60);
        var remMin = m % 60;
        var secStr = remSec < 10 ? "0" + remSec : String(remSec);
        if (h > 0) {
            var minStr = remMin < 10 ? "0" + remMin : String(remMin);
            return h + ":" + minStr + ":" + secStr;
        }
        return remMin + ":" + secStr;
    }

    function seek(offset) {
        if (activePlayer && activePlayer.canSeek) activePlayer.seek(offset);
    }

    function setPosition(pos) {
        if (activePlayer && activePlayer.positionSupported) activePlayer.position = pos;
    }

    function isPlayerActive(player) {
        if (!player) return false;
        if (player.playbackState === MprisPlaybackState.Stopped) return false;
        return player.playbackState === MprisPlaybackState.Playing || player.playbackState === MprisPlaybackState.Paused;
    }

    function selectActivePlayer() {
        var players = Mpris.players.values;
        if (!players || players.length === 0) {
            activePlayer = null;
            return;
        }

        // 1. Any player currently playing has first priority
        for (var i = 0; i < players.length; i++) {
            var p = players[i];
            if (p && p.isPlaying) {
                activePlayer = p;
                return;
            }
        }

        // 2. If current activePlayer is still in players list and active, preserve it
        if (activePlayer && players.indexOf(activePlayer) !== -1 && isPlayerActive(activePlayer)) {
            return;
        }

        // 3. Otherwise find any paused player
        for (var j = 0; j < players.length; j++) {
            var p2 = players[j];
            if (isPlayerActive(p2)) {
                activePlayer = p2;
                return;
            }
        }

        // 4. Fallback to any player with a track title that is not stopped
        for (var k = 0; k < players.length; k++) {
            var p3 = players[k];
            if (p3 && p3.playbackState !== MprisPlaybackState.Stopped && (p3.trackTitle || "") !== "") {
                activePlayer = p3;
                return;
            }
        }

        // None active
        activePlayer = null;
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            root.selectActivePlayer();
        }
    }

    Connections {
        target: root.activePlayer
        ignoreUnknownSignals: true
        function onPlaybackStateChanged() { root.selectActivePlayer(); }
        function onIsPlayingChanged() { root.selectActivePlayer(); }
    }

    // Periodic check to catch external events or unnotified changes
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.selectActivePlayer()
    }

    Component.onCompleted: selectActivePlayer()

    // Playback control helpers
    function togglePlaying() {
        if (!activePlayer) return;
        if (activePlayer.isPlaying) {
            if (activePlayer.canPause) {
                activePlayer.pause();
            } else {
                activePlayer.togglePlaying();
            }
        } else {
            if (activePlayer.canPlay) {
                activePlayer.play();
            } else {
                activePlayer.togglePlaying();
            }
        }
    }

    function play() {
        if (activePlayer && activePlayer.canPlay) activePlayer.play();
    }

    function pause() {
        if (activePlayer && activePlayer.canPause) activePlayer.pause();
    }

    function previous() {
        if (activePlayer && activePlayer.canGoPrevious) activePlayer.previous();
    }

    function next() {
        if (activePlayer && activePlayer.canGoNext) activePlayer.next();
    }

    function raise() {
        if (activePlayer && activePlayer.canRaise) activePlayer.raise();
    }
}
