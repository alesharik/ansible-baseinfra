#!/bin/bash
export GIT_SSH_COMMAND='ssh -i /id_ecdsa'
cd /var/www && git pull