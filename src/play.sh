# player wrap for giocon.client
# casa@ujo.guru 2019

pv -V >/dev/null || sudo apt install pv
mpsyt --ver >>/dev/null || play.install

play.main () {

    argument="$1"; shift
    show_video="True"                                           # mpsyt believes only "True" with the capital t
    search_music="True"
    mpsyt=true                                                  # bash uses true lover case

    case "$argument" in
            install)            play.install $@ ;;
            help|h)             play.help $@ ;;
            stop|end)           play.silence $@ ;;
            vt|text|ascii)      play.text $@ ;;
            demo)               play.demo ;;
            beer_break)         play.beer ;;
            enter)              cvlc $GURU_LOCAL_AUDIO/system/enter.mp4 --play-and-exit; exit 0;;
            song|biisi|kappale) to_play="/$@, 1, q"; show_video="False"; ;;
            karaoke|lyrics)     to_play="/$@ lyrics, 1, q" ;;
            video|youtube)      to_play="/$@, 1-, q"; search_music="False" ;;
            album|albumi)       to_play="album $@, 1-, q" ;;
            url|id)             to_play="url $@, 1, q" ;;
            world-news|news)    to_play="url $(cat $GURU_CFG/news-live.pl)"; search_music="False" ;;
            bg|backroung)       to_play="//$@, $((1 + RANDOM % 6)), 1-, q" ; show_video="False" ;;
            music-video)        to_play="/$@, 1-, q" ;;
            upgrade)            sudo -H pip3 install --upgrade youtube_dl
                                sudo apt-get install mpv    # change mplayer to mpv to
                                mpsyt set player mpv        # prevent player premature coetus interraptus
                                exit $? ;;
            something|random)   random=$(shuf -n1  /usr/share/dict/words)
                                $GURU_CALL trans -b -p "$random"
                                to_play="/$random, 1-, q"; show_video="False" ;;
            jotain)
                                random=$($GURU_CALL trans -b -p en:fi "$(shuf -n1 /usr/share/dict/words)")
                                echo "$random"
                                to_play="/$random, 1-, q"; show_video="False" ;;
            "")                 to_play="/nyan cat, 1, q" ;;
            *)                  to_play="/$argument $@, 1-, q"; show_video="False" ;;
    esac

    if [ $mpsyt ]; then
        pkill mpsyt                                                                     #; echo to_play: $to_play
        show_video="set show_video $(printf '%s' "${show_video[@]^}")"                 #; echo $show_video, (+re capital initial to be sure)
        search_music="set search_music $(printf '%s' "${search_music[@]^}")"           #; echo $search_music (+re capital initial)
        command="mpsyt $show_video, $search_music, $to_play"                            #; echo $command
        gnome-terminal --geometry=80x28 --zoom=0.75 -- /bin/bash -c "$command; exit; $SHELL; "
    fi
}


play.help () {
    echo "-- guru tool-kit play help -----------------------------------------------"
    printf "usage: %s play COMMAND what-to-play \n" "$GURU_CALL"
    printf "\ncommands: \n"
    printf "  url|id         play youtube ID or full url \n"
    printf "  video|youtube  search and play video \n"
    printf "  song|music|by  search and play music with video \n"
    printf "  background|bg  search and play play list without video output \n"
    printf "  karaoke        force to find lyrics for songs \n"
    printf "  stop|end       stop and kill player \n"
    printf "  demo           run demo "
    printf "  vt|text        play vt100 animations \n"
    printf "  upgrade        upgrade player \n"
}


play.silence () {
    exec 3>&2                        # This method removes all stdin messages when >/dev/null is not enough
    exec 2> /dev/null
        pkill mpsyt
        pkill pv
    exec 2>&3
    return 0

}


play.install () {
    # install

    sudo apt-get -y install mplayer python3-pip pulseaudio amixer pkill gnome-terminal
    sudo -H pip3 install --upgrade pip
    sudo -H pip3 install setuptools mps-youtube
    sudo -H pip3 install --upgrade youtube_dl
    pip3 install mps-youtube --upgrade
    sudo apt-get install mpv mplayer    # both mplayer to mpv to support easy change
    error=$?
    sudo ln -s /usr/local/bin/mpsyt /usr/bin/mpsyt    # hmm..
    mpsyt set player mpv                # prevent player premature coetus interraptus
    [ $error ] && echo $error
    return $error
}


play.text() {
    # Play text based videos on terminal window.
    # Uses htps://artscene.textfiles.com as source
    # local storage is checked before download
    # Dowloaded files ase saved to $GURU_LOCAL_VIDEO/vt
    video_name="$1"
    video="$GURU_LOCAL_VIDEO/vt/$1.vt"

    case "$1" in

        list)
                more" $GURU_CFG/$GURU_USER/vt.list"
                ;;

        locale|local)
                files=$(basename "$(ls $GURU_LOCAL_VIDEO|grep vt| cut -f1 -d".")")
                echo $files
                ;;

        help|-h|--help)
                echo "Usage: $GURU_CALL play text COMMAD or what-to-play"
                echo "Commands:"
                printf "list            list of videos on artscene.textfiles.com \n"
                printf "local|locale    local videos\n"
                echo 'check list, "'$GURU_CALL' play text list" then "'$GURU_CALL' play text <what-found-in-list>" '
                ;;
            *)
                if ! [ -f $video ]; then
                    cat" $GURU_CFG/$GURU_USER/vt.list" |grep $video_name && wget -N -P $GURU_LOCAL_VIDEO http://artscene.textfiles.com/vt100/$1.vt || echo "no video"
                fi

                cat "$video" | pv -q -L 2000
    esac
    return 0
}


play.demo() {

    audio=$GURU_AUDIO_ENABLED
    clear

    if $audio; then
        $GURU_CALL fadedown
        pkill mplayer
        pkill xplayer
        mplayer >>/dev/null && mplayer -ss 2 -novideo $GURU_LOCAL_MUSIC/fairlight.m4a </dev/null >/dev/null 2>&1 &
        $GURU_CALL fadeup
    fi

    guru play vt twilight
    printf "\n                             akrasia.ujo.guru \n"

    if $audio; then
        $GURU_CALL fadedown
        pkill mplayer
        mplayer >>/dev/null && mplayer -ss 1 $GURU_LOCAL_MUSIC/satelite.m4a </dev/null >/dev/null 2>&1 &
        $GURU_CALL fadeup
    fi

    guru play vt jumble
    printf "\n                    http://ujo.guru - ujoguru.slack.com \n"

    if $audio; then
        $GURU_CALL fadedown
        pkill mplayer
    fi
    return 0
}


play.beer () {

    resize -s 24 66

    if $GURU_AUDIO_ENABLED; then
        guru play volume 50
        guru play classical music valze
    fi

    while true; do
        guru play vt tauko
        read -n 1 -t 3 input
        if [[ $input ]];
            then
            echo
            break
        fi

    done

    if $GURU_AUDIO_ENABLED; then
        guru play stop
    fi

    clear
    return 0
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    play.main "$@"
    exit $?
fi

