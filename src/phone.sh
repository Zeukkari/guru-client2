#!/bin/bash
# guru tool-kit phone tools
# get files from phone by connecting phone sshd
# install this to phone: https://play.google.com/store/apps/details?id=com.theolivetree.sshserver

source $GURU_BIN/lib/common.sh
source $GURU_BIN/mount.sh
source $GURU_BIN/tag.sh

GURU_VERBOSE=1
#GURU_FORCE=true

if ((GURU_VERBOSE>1)) ; then phone_verb="-v" ; fi

phone_temp_folder="/tmp/guru/phone"
phone_file_count=0
phone_server_url="https://play.google.com/store/apps/details?id=com.theolivetree.sshserver"
phone_config_file="$GURU_CFG/$GURU_USER/phone.locations.cfg"

phone.main () {

    [[ $GURU_PHONE_IP ]]        || read -p "phone ip: "     GURU_PHONE_IP
    [[ $GURU_PHONE_PORT ]]      || read -p "sshd port: "    GURU_PHONE_PORT
    [[ $GURU_PHONE_USER ]]      || read -p "ssh user: "     GURU_PHONE_USER
    [[ $GURU_PHONE_PASSWORD ]]  || read -p "password: "     GURU_PHONE_PASSWORD

    local _cmd="$1" ; shift
    case "$_cmd" in
                    mount|unmount|terminal)  phone.$_cmd "$1"         ;;  # tools
                              media|camera)  phone.$_cmd              ;;  # phone locations
                                      help)  phone.help               ;;
                                       all)  phone.media
                                             phone.camera             ;;
                            install|server)  sudo apt install sshpass sshfs fusermount
                                             $GURU_BROWSER $phone_server_url ;;
                                         *)  echo "unknown action $_cmd"
        esac
}


phone.help () {
    echo "-- guru tool-kit phone help -----------------------------------------------"
    printf "usage:\t %s phone [action] \n" "$GURU_CALL"
    printf "\nactions:\n"
    printf " terminal          open terminal to phone \n"
    printf " mount             mount phone user folder \n"
    printf " unmount           unmount phone \n"
    printf " camera            get, tag and relocate photos and videos from phone \n"
    printf " whatsapp          get WhatsApp media from phone \n"
    printf " telegram          get Telegram media from phone \n"
    printf " downloads         get download folder from phone \n"
    printf " pictures       get pictures from phone \n"
    printf " install           install server to phone (google play) \n"
    printf " help              help printout \n"
    printf "\nexample:     %s phone mount \n" "$GURU_CALL"
    printf "             %s phone camera \n" "$GURU_CALL"
    printf "             %s phone terminal \n" "$GURU_CALL"
}


phone.terminal () {
    sshpass -p "$GURU_PHONE_PASSWORD" ssh -o HostKeyAlgorithms=+ssh-dss "$GURU_PHONE_USER@$GURU_PHONE_IP" -p "$GURU_PHONE_PORT"
}


phone.mount () {
    # mount phone folder set as in phone ssh server settings
    local _mount_point="$HOME/phone-$GURU_PHONE_USER" ; [[ "$1" ]] && _mount_point="$1"
    if [[ -d "$_mount_point" ]] ; then mkdir -p "$_mount_point" ; fi
    sshfs -o HostKeyAlgorithms=+ssh-dss -p "$GURU_PHONE_PORT" "$GURU_PHONE_USER@$GURU_PHONE_IP:/storage/emulated/0" "$_mount_point"
    return $?
}


phone.unmount () {
    local _mount_point="$HOME/phone-$GURU_PHONE_USER" ; [[ "$1" ]] && _mount_point="$1"
    fusermount -u "$_mount_point" || sudo fusermount -u "$_mount_point"
    [[ -d "$_mount_point" ]] && rmdir "$_mount_point"
    return $?
}


phone.rmdir () {
    # removes folder
    local _target_folder="$1"
    msg "\n${WHT}removing: $_target_folder ${NC}"
    sshpass -p "$GURU_PHONE_PASSWORD" ssh "$GURU_PHONE_USER@$GURU_PHONE_IP" -p "$GURU_PHONE_PORT" -o "HostKeyAlgorithms=+ssh-dss" "rm -rf $_target_folder"
    #return $?
}


phone.rm () {
    # removes files  /storage/emulated/0/DCIM/Camera/*.jpg
    local _target_files="$1"  # _target_files="/storage/emulated/0/DCIM/Camera/*.jpg"
    msg "\n${WHT}removing: $_target_files ${NC}"
    sshpass -p "$GURU_PHONE_PASSWORD" ssh "$GURU_PHONE_USER@$GURU_PHONE_IP" -p "$GURU_PHONE_PORT" -o "HostKeyAlgorithms=+ssh-dss" "rm -f $_target_files" \
        && REMOVED || IGNORED
    #return $?
}


phone.process_photos () {
     # analyze, tag and relocate photo files
    local _photo_format="jpg"
    mount.online $GURU_LOCAL_PHOTOS || mount.known_remote photos

    local _file_list=($(ls "$phone_temp_folder" | grep ".$_photo_format" ))                                      # read file list

    if [[ ${_file_list[@]} ]]; then
            msg "${WHT}tagging and moving photos to $GURU_LOCAL_PHOTOS ${NC}"
            local _year=1970
            local _month=1
            local _date=
            local _recognized=

            for _file in ${_file_list[@]}; do
                    # count and printout
                    phone_file_count=$((phone_file_count+1))
                    [[ "$GURU_VERBOSE" ]] && printf "."

                    # get date for location
                    _date=${_file#*_} ; _date=${_date%_*} ; _date=${_date%_*} ; _date=${_date%_*}   #; echo "date: $_date"
                    _year=$(date -d $_date +'%Y' || date +'%Y')                                     #; echo "year: $_year"
                    _month=$(date -d $_date +'%m' || date +'%m')                                    #; echo "month: $_month"

                    # tag file
                    tag_main "$phone_temp_folder/$_file" add "phone photo $_date" >/dev/null 2>&1         # $_recognized

                    # move file to target location
                    if ! [[ -d $GURU_LOCAL_PHOTOS/$_year/$_month ]] ; then mkdir -p "$GURU_LOCAL_PHOTOS/$_year/$_month" ; fi
                    mv "$phone_temp_folder/$_file" "$GURU_LOCAL_PHOTOS/$_year/$_month" || FAILED "phone.get_camera_files: file $phone_temp_folder/$_file nto found"  # place pictures to right folders
                done
                [[ "$GURU_VERBOSE" ]] && DONE
        else
            echo "no new photos"
        fi
}


phone.process_videos () {
    # analyze, tag and relocate video files
    local _video_format="mp4"
    mount.online $GURU_LOCAL_VIDEO || mount.known_remote video

    local _file_list=($(ls "$phone_temp_folder" | grep ".$_video_format" ))                             # read file list

    if [[ ${_file_list[@]} ]]; then
            msg "${WHT}moving videos to $GURU_LOCAL_VIDEO ${NC}"
            local _year=1970

            for _file in ${_file_list[@]}; do
                    # count and printout
                    phone_file_count=$((phone_file_count+1))
                    [[ "$GURU_VERBOSE" ]] && printf "."

                    # get date for location
                    _date=${_file#*_} ; _date=${_date%_*}                                   #; echo "date: $_date"
                    _year=$(date -d $_date +'%Y') || _year=$(date +'%Y')                    #; echo "year: $_year"

                    # move file to target location
                    if ! [[ -d $GURU_LOCAL_VIDEO/$_year ]] ; then mkdir -p "$GURU_LOCAL_VIDEO/$_year" ; fi
                    mv "$phone_temp_folder/$_file" "$GURU_LOCAL_VIDEO/$_year" || FAILED "phone.get_camera_files: file $phone_temp_folder/$_file not found"            # place videos to right folders
                done
                [[ "$GURU_VERBOSE" ]] && echo
        else
            echo "no new videos"
        fi
}


phone.camera () {

    phone.process_photos
    phone.process_videos

    local _left_over=$(ls $phone_temp_folder)
    if [[ "$_left_over" ]] ; then
            echo "leftover files: $(ls $phone_temp_folder)"
            read -t 10 -p "remove leftovers from temp? : " _answ
            if [[ "$_answ" == "y" ]] ; then
                    # few checks to avoid 'rm -rf $HOME' or 'sudo rm -rf /' type if some of the variables are emty
                    [[ ${#phone_temp_folder} > 5 ]] && [[ -d "$phone_temp_folder" ]] && rm -rf "$phone_temp_folder"
                fi
        fi

    if ((phone_file_count<1)) ; then
            return 0
        fi

    printf "${WHT}%s files processed${NC}\n" "$phone_file_count"
    read -t 10 -p "remove source files from phone? : " _answ
    if [[ $GURU_FORCE ]] || [[ "$_answ" == "y" ]] ; then
            phone.rmdir "/storage/emulated/0/DCIM/Camera"
        fi
}


phone.media () { # Get all audio files from phone

    mount.online $GURU_LOCAL_PICTURES || mount.known_remote pictures
    mount.online $GURU_LOCAL_DOCUMENTS || mount.known_remote documents
    mount.online $GURU_LOCAL_VIDEO || mount.known_remote video
    mount.online $GURU_LOCAL_AUDIO || mount.known_remote audio

    while IFS= read -r _line ; do
            IFS='>' ; _list=($_line) ; IFS=           #; echo "${_list[0]}:${_list[1]}:${_list[2]}"
            _action=${_list[0]}                       #; echo ":$_action:"   # cp=copy, mv=move
            _type=${_list[1]}                         #; echo ":$_type:"     # filetype
            _title=${_list[2]}                        #; echo ":$_title:$_source:$_target:"
            _source=${_list[3]}
            _target=$(eval echo "${_list[4]}")

            msg "${WHT}$_title > $_target.. ${NC}"
            if ! [[ -d "$_target" ]] ; then mkdir -p "$_target" ; fi

            sshpass -p $GURU_PHONE_PASSWORD \
            scp $phone_verb -p -o HostKeyAlgorithms=+ssh-dss -P $GURU_PHONE_PORT \
            $GURU_PHONE_USER@$GURU_PHONE_IP:"$_source/*.$_type" $_target

            case $? in
                    0)  DONE ; [[ "$_action" == "mv" ]] && echo phone.rmdir "$_source" ;;  # /*.$_type" ;; # does not work cause *
                    *)  FAILED
                esac

        done < "$phone_config_file"
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]] ; then
        sshpass -V >/dev/null || sudo apt install sshpass
        source "$HOME/.gururc"
        phone.main "$@"
    fi



# "Telegram/Telegram Audio"
# "Telegram/Telegram Documents"
# "WhatsApp/Media/WhatsApp Documents"
# "Telegram/Telegram Images"
# "Telegram/Telegram Video"
# "WhatsApp/Media/WhatsApp Animated Gifs"
# "WhatsApp/Media/WhatsApp Audio"
# "WhatsApp/Media/WhatsApp Images"
# "WhatsApp/Media/WhatsApp Video"
# "WhatsApp/Media/WhatsApp Voice Notes"

# if [[ "$GURU_PHONE_USER" = "casa" ]]; then
#   sshpass -p $GURU_PHONE_PASSWORD scp -v -r -p -oHostKeyAlgorithms=+ssh-dss -P $GURU_PHONE_PORT $GURU_PHONE_USER@$GURU_PHONE_IP:/storage/emulated/0/MyTinyScan/Documents/* $HOME/Documents
# fi
#${WHT}Timer${NC}

# rsync  -avzr -h --progress -e "ssh -oHostKeyAlgorithms=+ssh-dss -p$GURU_PHONE_PORT" maea@192.168.1.50:/storage/emulated/0/WhatsApp/Media/* $GURU_LOCAL_PHOTOS/2019/wa
# rsync  -avzr -h --progress -e "ssh -oHostKeyAlgorithms=+ssh-dss -p$GURU_PHONE_PORT" casa@192.168.1.29:/storage/emulated/0/WhatsApp/Media/* $GURU_LOCAL_PHOTOS/2019/wa
#   casa@192.168.1.29's password:
#   exec request failed on channel 0
#   rsync: connection unexpectedly closed (0 bytes received so far) [Receiver]
#   rsync error: unexplained error (code 255) at io.c(235) [Receiver=3.1.2]


# ssh -oHostKeyAlgorithms=+ssh-dss -p$GURU_PHONE_PORT casa@192.168.1.29
#   casa@192.168.1.29's password:
#   PTY allocation request failed on channel 0
#   /system/bin/sh: can't find tty fd: No such device or address
#   /system/bin/sh: warning: won't have full job control
#   casa@hwH60:/storage/emulated/0


# # get date for location
# if [[ "${_file%_*}" == "IMG" ]] ; then                                          # huaway type
#     _date=${_file#*_} ; _date=${_date%_*} ; _date=${_date%_*} ; _date=${_date%_*}   #; echo "date: $_date"

# elif date -d "${_file%-*}" +'%Y' ; then                                           # samsung type
#     _date="${_file%-*}" ; _date=${_date%_*} ; _date=${_date%_*} ; _date=${_date%_*}   #; echo "date: $_date"


# _recognized="$(yolo.regonize $_file)"                                         # "a dig"
# tag_main "$_target_files/$_file" rm  >/dev/null 2>&1                         # remove current tag (debug, new files should not be tagged)