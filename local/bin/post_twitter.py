#!/usr/bin/python3

import sys
import tweepy
import configparser
import io

config = configparser.RawConfigParser()

f = open('/home/hebcal/local/etc/hebcal-dot-com.ini', 'r')

output = io.StringIO()
output.write('[DEFAULT]\n')
output.write(f.read())
output.seek(0,0)

contents = output.getvalue()

config.read_string(contents)

CONSUMER_KEY = config.get('DEFAULT', 'hebcal.twitter.consumer_key')
CONSUMER_SECRET = config.get('DEFAULT', 'hebcal.twitter.consumer_secret')
ACCESS_KEY = config.get('DEFAULT', 'hebcal.twitter.access_key')
ACCESS_SECRET = config.get('DEFAULT', 'hebcal.twitter.access_secret')

auth = tweepy.OAuthHandler(CONSUMER_KEY, CONSUMER_SECRET)
auth.set_access_token(ACCESS_KEY, ACCESS_SECRET)
api = tweepy.API(auth)
api.update_status(sys.argv[1])
