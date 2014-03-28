#!/bin/bash
#the follow code canbe used to calculate the totoal time needed for some process run in backgroud
sleep 2 &
sleep 10 &
sleep 5 &
wait
