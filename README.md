# ArtistShare

A decentralized platform built on Stacks blockchain that enables musicians to share royalties with their fans through token-based engagement.

## Overview

ArtistShare is a smart contract platform that allows musicians to create direct financial relationships with their fans through automated royalty distribution. Artists can lock tokens and set royalty rates, while fans can subscribe to their favorite artists and participate in the success of their music.

## Features

### For Artists
- **Artist Registration**: Musicians can register on the platform with customized royalty rates
- **Token Locking**: Secure token locking mechanism for royalty distribution
- **Streaming Metrics**: Track total streams and earnings
- **Subscriber Management**: Monitor fan base growth and engagement

### For Fans
- **Artist Subscriptions**: Subscribe to favorite artists
- **Transparent Metrics**: View artist performance and streaming data
- **Automated Payments**: Receive royalty shares based on subscription status

## Smart Contract Functions

### Public Functions

1. `register-artist`
   - Parameters: `royalty-rate: uint`
   - Registers a new artist with specified royalty rate

2. `lock-tokens`
   - Parameters: `amount: uint`
   - Allows artists to lock tokens for royalty distribution

3. `subscribe-to-artist`
   - Parameters: `artist: principal`
   - Enables fans to subscribe to their chosen artist

### Read-Only Functions

1. `get-artist-profile`
   - Parameters: `artist: principal`
   - Returns artist's profile data including locked tokens and royalty rate

2. `get-subscription-status`
   - Parameters: `artist: principal, subscriber: principal`
   - Checks subscription status between artist and fan

3. `get-streaming-metrics`
   - Parameters: `artist: principal`
   - Retrieves streaming and earnings data for an artist


