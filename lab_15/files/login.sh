#!/bin/bash
if getent group admin | grep -qw "$PAM_USER"; then
        exit 0
fi


if [ $(date +%a) = "Sat" ] || [ $(date +%a) = "Sun" ]; then
        exit 1
else
        exit 0
fi