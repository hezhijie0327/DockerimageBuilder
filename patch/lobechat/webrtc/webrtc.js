#!/usr/bin/env node

// WebRTC Signaling server for LobeChat
// ref: https://github.com/lobehub/y-webrtc-signaling

import { WebSocketServer } from 'ws'
import http from 'http'
import * as map from 'lib0/map'

// Environment variables for debug, host and port
const debug = process.env.WEBRTC_DEBUG === 'true'
const host = process.env.WEBRTC_HOST || '0.0.0.0'
const port = process.env.WEBRTC_PORT || 3000

// Get allowed topics from the environment variable and convert to a Set
const allowedTopics = new Set( ( process.env.WEBRTC_ALLOWED_TOPICS || '' ).split( ',' ).map( topic => topic.trim() ) )

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
        } )
        subscribedTopics.clear()
        closed = true

        debugLog( 'Client disconnected' )
    } )

    /**
     * Handle incoming messages from the client
     * @param {object} message - Incoming message
     */
    conn.on( 'message', ( message ) =>
    {
        debugLog( `Received message: ${ message }` )

        if ( typeof message === 'string' || message instanceof Buffer )
        {
            message = JSON.parse( message )
        }
        if ( message && message.type && !closed )
        {
            const invalidTopics = ( message.topics || [] ).filter( topicName => !allowedTopics.has( topicName ) )
            const handleInvalidTopic = () =>
            {
                debugLog( `Invalid topic(s) detected. Disconnecting client.` )
                conn.close()
            }

            if ( invalidTopics.length > 0 || ( message.type === 'publish' && !allowedTopics.has( message.topic ) ) )
            {
                handleInvalidTopic()
                return
            }

            switch ( message.type )
            {
                case 'subscribe':
                    ( message.topics || [] ).forEach( ( topicName ) =>
                    {
                        if ( typeof topicName === 'string' )
                        {
                            // Add connection to the topic
                            const topic = map.setIfUndefined( topics, topicName, () => new Set() )
                            topic.add( conn )
                            // Add topic to the connection's subscribed topics
                            subscribedTopics.add( topicName )

                            debugLog( `Client subscribed to topic: ${ topicName }` )
                        }
                    } )
                    break
                case 'unsubscribe':
                    ( message.topics || [] ).forEach( ( topicName ) =>
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
                    if ( message.topic )
                    {
                        const receivers = topics.get( message.topic )
                        if ( receivers )
                        {
                            message.clients = receivers.size
                            receivers.forEach( ( receiver ) => send( receiver, message ) )

                            debugLog( `Published message to topic: ${ message.topic }` )
                        }
                    }
                    break
                case 'ping':
                    send( conn, { type: 'pong' } )

                    debugLog( 'Received ping, sent pong' )
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
