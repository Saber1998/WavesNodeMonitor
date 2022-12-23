# WavesNodeMonitor
Script to monitor your Waves node to ensure uptime as well as Waves balance accumulation for payouts.

# Requirements
Windows running at least PowerShell version 3 (Will look into making it a Docker file to be able to be run without the Windows requirement at a later date.)

# Configuration
Follow scripts prompts to provide configuration data for node monitor. I.E. IP Address, Port that is open and Node Wallet Address.
Telegram API token is stored encrypted in JSON file instead of in plain text.

For instructions on how to create a Telegram Bot, please see 
https://core.telegram.org/bots

# Execution
Recommendation is to go to Start --> PowerShell (doesn't have to be elevated) go to the location script is saved and execute the script .\WavesNodeMonitor.ps1
Script is unsigned, so will likely need to allow it to run via a custom policy or set your PowerShell execution policy to unrestricted (Set-ExecutionPolicy unrestricted)


# Donation
If you like my work and feel its worthwhile buy me a beer. :)

Waves
3PFWASEmM4h4ZubsR5GKyMAasyhYzS1uPZH

Bitcoin
bc1qu78v2gt6rglfdtyssyykhuhd7p6fm40u8tzpc5

Litecoin
ltc1qjjj5kz3p3nywgn6us2akj4qpa4cf2n09wfvc8q