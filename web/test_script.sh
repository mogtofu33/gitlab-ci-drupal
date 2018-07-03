#!/usr/bin/env bash

echo "I am a script!"

# Run actions.
if [[ "${1:-}" =~ ^hi$ ]]
then
echo 'hi!'
elif [[ "${1:-}" =~ ^cheers$ ]]
then
echo 'cheers!'
elif [[ "${1:-}" =~ ^who$ ]]
then
echo "I am a script!"
else
echo "I am alone!"
fi
