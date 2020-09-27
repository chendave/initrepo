#!/bin/bash
pid=`ps -ef | grep edgecore | grep -v grep | awk -F " " '{print $2}'`
echo $pid
kill -9 $pid
