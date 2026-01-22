#!/bin/bash
cd /mnt/minecraft

# Use run.sh if it exists (Forge creates this), otherwise use server.jar
if [ -f run.sh ]; then
    # Forge server - use run.sh with custom JVM arguments
    # Edit the run.sh or use @user_jvm_args.txt for Forge 1.17+
    echo "-Xms2G" > user_jvm_args.txt
    echo "-Xmx3G" >> user_jvm_args.txt
    bash run.sh nogui
else
    # Vanilla or other server types
    java -Xms2G -Xmx3G -jar server.jar nogui
fi