#!/usr/bin/env python

import sys
import tweepy
import ConfigParser

config = ConfigParser.RawConfigParser()
config.read('/home/hebcal/local/etc/hebcal-dot-com.ini')

CONSUMER_KEY = config.get('DEFAULT', 'hebcal.twitter.consumer_key')
CONSUMER_SECRET = config.get('DEFAULT', 'hebcal.twitter.consumer_secret')
ACCESS_KEY = config.get('DEFAULT', 'hebcal.twitter.access_key')
ACCESS_SECRET = config.get('DEFAULT', 'hebcal.twitter.access_secret')

auth = tweepy.OAuthHandler(CONSUMER_KEY, CONSUMER_SECRET)
auth.set_access_token(ACCESS_KEY, ACCESS_SECRET)
api = tweepy.API(auth)
api.update_status(sys.argv[1])
