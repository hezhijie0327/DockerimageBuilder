#!/usr/bin/env node

// WebRTC Signaling server for LobeChat
// ref: https://github.com/lobehub/y-webrtc-signaling

import { WebSocketServer } from 'ws'
import http from 'http'
import * as map from 'lib0/map'

// Environment variables for allowed topics, debug, host and port
const allowedTopics = new Set( ( process.env.WEBRTC_ALLOWED_TOPICS || '' ).split( ',' ).map( topic => topic.trim() ) )
const debug = process.env.WEBRTC_DEBUG === 'true'
const host = process.env.WEBRTC_HOST || '0.0.0.0'
const port = process.env.WEBRTC_PORT || 3000

// Ping timeout interval in milliseconds
const pingTimeout = 30000

// Create an HTTP server
const server = http.createServer( ( request, response ) =>
{
    response.writeHead( 204 )
    response.end()
} )

// Create a new WebSocket server
const wss = new WebSocketServer( { noServer: true } )

// WebSocket ready states
const wsReadyState = {
    CONNECTING: 0,
    OPEN: 1,
    CLOSING: 2,
    CLOSED: 3,
}

/**
 * Conditional logging function
 * Logs messages to the console only if the debug mode is enabled.
 * @param {...any} args - The messages or objects to log
 */
const debugLog = ( ...args ) =>
{
    if ( debug )
    {
        console.log( ...args )
    }
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
        debugLog( `Sent message: ${ JSON.stringify( message ) }` )
    } catch ( e )
    {
        debugLog( 'Error sending message:', e )
        conn.close()
    }
}

/**
 * Setup a new client connection
 * @param {any} conn - WebSocket connection
 */
const onConnection = ( conn ) =>
{
    debugLog( 'New client connected' )

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
            debugLog( 'Ping not received, closing connection' )
            conn.close()
            clearInterval( pingInterval )
        } else
        {
            pongReceived = false
            try
            {
                conn.ping()
                debugLog( 'Ping sent' )
            } catch ( e )
            {
                debugLog( 'Error sending ping:', e )
                conn.close()
            }
        }
    }, pingTimeout )

    // Listen for pong responses to keep the connection alive
    conn.on( 'pong', () =>
    {
        pongReceived = true
        debugLog( 'Pong received' )
    } )

    // Handle connection close event
    conn.on( 'close', () =>
    {
        subscribedTopics.forEach( ( topicName ) =>
        {
            const subs = topics.get( topicName ) || new Set()
            subs.delete( conn )
            if ( subs.size === 0 )
            {
                topics.delete( topicName )
            }
            debugLog( `Client disconnected from topic: ${ topicName }` )
        } )
        subscribedTopics.clear()
        closed = true
        clearInterval( pingInterval )
        debugLog( 'Client fully disconnected' )
    } )

    // Handle incoming messages from the client
    conn.on( 'message', ( message ) =>
    {
        debugLog( `Received message: ${ message }` )

        if ( typeof message === 'string' || message instanceof Buffer )
        {
            message = JSON.parse( message )
        }

        if ( message && message.type && !closed )
        {
            const { type, topics: messageTopics, topic: messageTopic } = message

            const invalidTopics = ( messageTopics || [] ).filter( topicName => !allowedTopics.has( topicName ) )

            if ( invalidTopics.length > 0 || ( type === 'publish' && !allowedTopics.has( messageTopic ) ) )
            {
                debugLog( `Invalid topic(s) detected. Disconnecting client.` )
                conn.close()
                return
            }

            switch ( type )
            {
                case 'subscribe':
                    ( messageTopics || [] ).forEach( ( topicName ) =>
                    {
                        if ( typeof topicName === 'string' )
                        {
                            const topic = map.setIfUndefined( topics, topicName, () => new Set() )
                            topic.add( conn )
                            subscribedTopics.add( topicName )
                            debugLog( `Client subscribed to topic: ${ topicName }` )
                        }
                    } )
                    break
                case 'unsubscribe':
                    ( messageTopics || [] ).forEach( ( topicName ) =>
                    {
                        const subs = topics.get( topicName )
                        if ( subs )
                        {
                            subs.delete( conn )
                            debugLog( `Client unsubscribed from topic: ${ topicName }` )
                        }
                    } )
                    break
                case 'publish':
                    const receivers = topics.get( messageTopic )
                    if ( receivers )
                    {
                        message.clients = receivers.size
                        receivers.forEach( ( receiver ) => send( receiver, message ) )
                        debugLog( `Published message to topic: ${ messageTopic }` )
                    }
                    break
                case 'ping':
                    send( conn, { type: 'pong' } )
                    debugLog( 'Received ping, sent pong' )
                    break
            }
        }
    } )
}

// Set up WebSocket connection handler
wss.on( 'connection', onConnection )

// Handle HTTP upgrade requests to WebSocket
server.on( 'upgrade', ( request, socket, head ) =>
{
    debugLog( 'HTTP upgrade request received' )

    /**
     * Handle authentication (if necessary)
     * @param {any} ws - WebSocket connection
     */
    const handleAuth = ( ws ) =>
    {
        debugLog( 'WebSocket connection authenticated' )
        wss.emit( 'connection', ws, request )
    }
    wss.handleUpgrade( request, socket, head, handleAuth )
} )

// Start the HTTP server and bind it to the specified host and port
server.listen( port, host, () =>
{
    console.log( `WebRTC Signaling server running on ${ host }:${ port }` )
} )
