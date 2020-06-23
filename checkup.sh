#!/bin/bash

SPECIAL=';packages;pgme;fdi;'
EXCLUDE=';txt;docinfo;htm;'
LANGUAGES=''
APPLANGS=''
APPS=0
LANGS=0
TRANS=0

function summary () {

    echo "? unable to locate default English version"
    echo "! caution, English version is newer than translation"
    echo "* problem, either missing or extras keys"
    echo

}

function script_help () {

    echo "usage: ${0##*/} program"
    echo
    summary
}

function get_stamp () {
    stat -f%m "${*}" 2>/dev/null
    if [[ $? -ne 0 ]] ; then
        echo 0
        return 1
    fi
    return 0
}

function load_nls () {

    # echo load "${2}"
    unset ${1}
    local line flag hold t
    if [[ -f "${2}" ]] ; then
        hold=$( while [[ ! $flag ]] ; do
            read -r line || flag=done
            line="${line//[$'\t\r\n']}"
            line="${line#${line%%[![:space:]]*}}"
            line="${line%${line##*[![:space:]]}}"
            t="${line}"
            line="${line%%:*}"
            line="${line%%=*}"
            [[ "${line}" == "" ]] && continue
            [[ "${t}" == "${line}" ]] && continue
            line="${line%${line##*[![:space:]]}}"
            [[ "${line// }" != "${line}" ]] && continue
            [[ "${line:0:1}" == "#" ]] && continue
            [[ "${line:0:1}" == ";" ]] && continue
            echo "${line};"
        done< "${2}" | sort -u )
    else
        hold="${2}"
    fi
    hold="${hold//[$'\t\r\n']}"
    if [[ "${hold}" != "" ]] ; then
        read -r ${1} <<<";${hold}"
    elif [[ "${2}" != "${EN}" ]] ; then
        EN_DATA="${EN}"
    fi

}

function compare_nls () {

    local t x d n
    local p="${1%/*}"
    p="${p##*/}"
    EN_CMP=''
    if [[ ${EN_STAMP} -eq 0 ]] ; then
        EN_CMP='?'
    elif [[ "${p}" == "nls" ]] ; then
        [[ "${EN_DATA}" == "" ]] && load_nls EN_DATA "${EN}"
        unset NLS_DATA
        load_nls NLS_DATA "${1}"
        if [[ "${EN_DATA}" == "${EN}" ]] ; then
            UC=yes
        elif [[ "${NLS_DATA}" != "${EN_DATA}" ]] ; then
            EN_CMP="*"

            [[ ${NO_REP} ]] && return 0
            t="${EN_DATA}"
            d=
            while [[ ${#t} -ne 0 ]] ; do
                x="${t%%;*}"
                t="${t:$(( ${#x} + 1 ))}"
                n="${NLS_DATA//;${x};/;}"
                if [[ "${n}" == "${NLS_DATA}" ]] ; then
                    d="${d};${x}"
                else
                    NLS_DATA="${n}"
                fi
            done
            d="${d//;;/;}"
            d="${d:1}"
            if [[ "${d}" != '' ]] ; then
                [[ ! ${KEY_BR} ]] && echo
                KEY_BR=yes
                echo "translation file '${1}' is missing key(s): '${d//;/, }'"
            fi
            d="${NLS_DATA//;;/;}"
            [[ ${#d} -gt 1 ]] && d="${d:1:$(( ${#d} - 2 ))}" || d=''
            if [[ "${d}" != '' ]] ; then
                [[ ! ${KEY_BR} ]] && echo
                KEY_BR=yes
                echo "translation file '${1}' has extra key(s): '${d//;/, }'"
            fi
        # else
            # echo "${1}"
            # echo "${EN_DATA}"
            # echo "${NLS_DATA}"
            # echo
        fi
    else
        UC=yes
    fi

    if [[ "${EN_CMP}" == "" ]] ; then
        t=$(get_stamp "${1}")
        [[ ${t} -lt ${EN_STAMP} ]] && EN_CMP='!'
    fi

    return 0

}

function lang_of_nls () {

    local t=$(echo "${1}" | tr "[:upper:]" "[:lower:]")
    t="${t##*/}"
    t="${t#*.}"
    t="${t%.*}"
    [[ "${EXCLUDE//;${t};}" != "${EXCLUDE}" ]] && return 0
    echo "${t}"

}

function calc_add_language () {

    local i="${1}"
    local x="${i//\*}"
    x="${x//!}"
    x="${x//\?}"
    [[ "${x}" == "" ]] && return 0
    [[ "${LANGUAGES}" = '' ]] && LANGUAGES=";"
    [[ "${APPLANGS}" = '' ]] && APPLANGS=";"
    if [[ "${LANGUAGES//;${x};}" == "${LANGUAGES}" ]] ; then
        LANGUAGES="${LANGUAGES}${x};"
        (( LANGS++ ))
    fi
    if [[ "${APPLANGS//;${i};}" == "${APPLANGS}" ]] && \
    [[ "${APPLANGS//;${i}\*;}" == "${APPLANGS}" ]] && \
    [[ "${APPLANGS//;${i}\?;}" == "${APPLANGS}" ]] && \
    [[ "${APPLANGS//;${i}!;}" == "${APPLANGS}" ]] \
     ; then
        APPLANGS="${APPLANGS}${i};"
    fi

}

function calc_dir_languages () {

    [[ ! -d "${1}" ]] && return 1
    local i utf l
    unset EN
    unset EN_STAMP
    unset EN_DATA
    for i in "${1}"/* ; do
        [[ ! -e "${i}" ]] && continue
        if [[ "${EN}" == "" ]] ; then
            EN="${1}/${1%%/*}.en"
            if [[ ! -e "${EN}" ]] ; then
                l=$(ls -a1d "${1}"/*.en 2>/dev/null | wc -l )
                [[ ${l} -eq 1 ]] && EN=$(ls -a1d "${1}"/*.en)
            fi
            EN_STAMP=$(get_stamp "${EN}")
            [[ ! -e "${EN}" ]] && UC=fail
        fi
        utf=$(ls -1d "${i}"* 2>/dev/null | grep -i "${i}\.utf-8" )
        [[ "${utf}" != "" ]] && continue
        l=$(lang_of_nls "${i}")
        [[ "${l}" == "" ]] && continue

        if [[ "${l}" == 'en' ]] ; then
            calc_add_language "${l}"
        else
            compare_nls "$i"
            calc_add_language "${l}${EN_CMP}"
        fi
        (( TRANS++ ))
    done

    return 0
}

function calc_src_languages () {

    [[ ! -d "${1}" ]] && return 1
    US=yes
    local i utf l
    for i in "${1}"/* ; do
        [[ ! -e "${i}" ]] && continue
        utf=$(ls -1d "${i}"* 2>/dev/null | grep -i "${i}\.utf-8" )
        [[ "${utf}" != "" ]] && continue
        case "${1%%/*}" in
            ctmouse)
                i="${i//.MSG}"
                i="${i//CTM-/CTM.}"
                :;
            ;;
            mkeyb)
                return 1
            ;;
            *)
            calc_dir_languages ${1%%/*}/source
            return $?
        esac
        l=$(lang_of_nls "${i}")
        [[ "${l}" == "" ]] && continue
        calc_add_language "${l}?"
        (( TRANS++ ))
    done
    return 0
}

function calc_languages () {

    APPLANGS=''
    local prog
    unset UC
    unset KEY_BR
    calc_dir_languages ${1}/nls && prog=y
    calc_dir_languages ${1}/doc && prog=y
    calc_dir_languages ${1}/help && prog=y
    calc_src_languages ${1}/source && prog=y

    if [[ "${prog}" == "y" ]] ; then
        (( APPS++ ))
        APPLANGS="${APPLANGS:1:$(( ${#APPLANGS} - 2))}"
        APPLANGS="${APPLANGS//;/, }"
        /bin/echo -n "${1}: ${APPLANGS}"
        [[ ${UC} ]] && /bin/echo -n " (compare manually)"
        echo
        sleep 1
    fi

    return 0

}

function each_app () {

    local app
    for app in * ; do
        [[ ! -d "${app}" ]] && continue
        [[ "${SPECIAL//;${app};}" != "${SPECIAL}" ]] && continue
        ${1} ${app}
    done

}


function main () {

    local opt i
    local once=yes

    while [[ "${1}" != "" ]] || [[ $once ]]; do
        unset once
        opt="${1}"
        shift
        if [[ "${opt}" == "-h" ]] ; then
            script_help
            return 0
        elif [[ "${opt}" == "-n" ]] ; then
            NO_REP=yes      # don't show key comparisons
        elif [[ "${opt}" == "-s" ]] || [[ "${opt}" == "" ]] ; then
            # summary
            each_app calc_languages
        else
            # summary
            calc_languages "${opt}"
        fi
    done

    echo
    echo "${APPS} total programs, ${LANGS} total languages, ${TRANS} total translations"
    LANGUAGES=$(for i in ${LANGUAGES//;/ } ; do echo "${i}, "; done | sort | tr -d "[:cntrl:]")
    [[ "${LANGUAGES}" != "" ]] && LANGUAGES="${LANGUAGES:0:$(( ${#LANGUAGES} - 2))}" || LANGUAGES="(none)"
    echo "Languages: ${LANGUAGES}"

}

main ${@}