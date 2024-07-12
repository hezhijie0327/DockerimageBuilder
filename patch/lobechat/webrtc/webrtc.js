#!/usr/bin/env node

// WebRTC Signaling server for LobeChat
// ref: https://github.com/lobehub/y-webrtc-signaling

import { WebSocketServer } from 'ws'
import http from 'http'
import * as map from 'lib0/map'

// Environment variables for port and host
const host = process.env.WEBRTC_HOST || '0.0.0.0'
const port = process.env.WEBRTC_PORT || 3001

// Create an HTTP server
const server = http.createServer( ( request, response ) =>
{
    response.writeHead( 204 )
    response.end()
} )

// Create a new WebSocket server
const wss = new WebSocketServer( { noServer: true } )

// Ping timeout interval in milliseconds
const pingTimeout = 30000

// WebSocket ready states
const wsReadyState = {
    CONNECTING: 0,
    OPEN: 1,
    CLOSING: 2,
    CLOSED: 3
}

/**
 * Map from topic-name to set of subscribed clients.
 * @type {Map<string, Set<any>>}
 */
const topics = new Map()

/**
 * Send a message to a WebSocket connection
 * @param {any} conn - WebSocket connection
 * @param {object} message - Message to send
 */
const send = ( conn, message ) =>
{
    if ( conn.readyState !== wsReadyState.CONNECTING && conn.readyState !== wsReadyState.OPEN )
    {
        conn.close()
    }
    try
    {
        conn.send( JSON.stringify( message ) )
    } catch ( e )
    {
        conn.close()
    }
}

/**
 * Setup a new client connection
 * @param {any} conn - WebSocket connection
 */
const onConnection = conn =>
{
    /**
     * Set of topics subscribed by the client
     * @type {Set<string>}
     */
    const subscribedTopics = new Set()
    let closed = false

    // Check if connection is still alive
    let pongReceived = true
    const pingInterval = setInterval( () =>
    {
        if ( !pongReceived )
        {
            conn.close()
            clearInterval( pingInterval )
        } else
        {
            pongReceived = false
            try
            {
                conn.ping()
            } catch ( e )
            {
                conn.close()
            }
        }
    }, pingTimeout )

    // Listen for pong responses to keep the connection alive
    conn.on( 'pong', () =>
    {
        pongReceived = true
    } )

    // Handle connection close event
    conn.on( 'close', () =>
    {
        subscribedTopics.forEach( topicName =>
        {
            const subs = topics.get( topicName ) || new Set()
            subs.delete( conn )
            if ( subs.size === 0 )
            {
                topics.delete( topicName )
            }
        } )
        subscribedTopics.clear()
        closed = true
    } )

    /**
     * Handle incoming messages from the client
     * @param {object} message - Incoming message
     */
    conn.on( 'message', message =>
    {
        if ( typeof message === 'string' || message instanceof Buffer )
        {
            message = JSON.parse( message )
        }
        if ( message && message.type && !closed )
        {
            switch ( message.type )
            {
                case 'subscribe':
                    ( message.topics || [] ).forEach( topicName =>
                    {
                        if ( typeof topicName === 'string' )
                        {
                            // Add connection to the topic
                            const topic = map.setIfUndefined( topics, topicName, () => new Set() )
                            topic.add( conn )
                            // Add topic to the connection's subscribed topics
                            subscribedTopics.add( topicName )
                        }
                    } )
                    break
                case 'unsubscribe':
                    ( message.topics || [] ).forEach( topicName =>
                    {
                        const subs = topics.get( topicName )
                        if ( subs )
                        {
                            subs.delete( conn )
                        }
                    } )
                    break
                case 'publish':
                    if ( message.topic )
                    {
                        const receivers = topics.get( message.topic )
                        if ( receivers )
                        {
                            message.clients = receivers.size
                            receivers.forEach( receiver => send( receiver, message ) )
                        }
                    }
                    break
                case 'ping':
                    send( conn, { type: 'pong' } )
            }
        }
    } )
}

// Set up WebSocket connection handler
wss.on( 'connection', onConnection )

// Handle HTTP upgrade requests to WebSocket
server.on( 'upgrade', ( request, socket, head ) =>
{
    /**
     * Handle authentication (if necessary)
     * @param {any} ws - WebSocket connection
     */
    const handleAuth = ws =>
    {
        wss.emit( 'connection', ws, request )
    }
    wss.handleUpgrade( request, socket, head, handleAuth )
} )

// Start the HTTP server and bind it to the specified host and port
server.listen( port, host, () =>
{
    console.log( `WebRTC Signaling server running on ${ host }:${ port }` )
} )
