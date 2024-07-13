#!/usr/bin/env node

import { WebSocketServer } from 'ws'
import http from 'http'

// Configuration object
const CONFIG = {
    logLevel: process.env.WEBRTC_LOG_LEVEL || 'notice', // 'debug', 'info', 'notice', 'error', or 'none'

    host: process.env.WEBRTC_HOST || '0.0.0.0',
    port: process.env.WEBRTC_PORT || 3000,

    allowedTopics: new Set( ( process.env.WEBRTC_ALLOWED_TOPICS || '' ).split( ',' ).map( topic => topic.trim() ) ),

    pingTimeout: process.env.WEBRTC_PING_TIMEOUT || 30000
}

// Logging function
const log = ( level, ...args ) =>
{
    const levels = [ 'debug', 'info', 'notice', 'error', 'none' ]
    const configLevelIndex = levels.indexOf( CONFIG.logLevel )
    const messageLevelIndex = levels.indexOf( level )

    if ( configLevelIndex < 4 && messageLevelIndex >= configLevelIndex )
    {
        console.log( `[${ level.toUpperCase() }]`, ...args )
    }
}

// Map to store topics and their subscribed connections
const topics = new Map()

/**
 * Send a message to a WebSocket connection
 * @param {WebSocket} conn - The WebSocket connection
 * @param {object} message - The message to send
 */
const send = ( conn, message ) =>
{
    /**
     * WebSocket ready states:
     * CONNECTING: 0
     * OPEN: 1
     * CLOSING: 2
     * CLOSED: 3
     */
    if ( conn.readyState > 1 )
    {
        log( 'debug', 'Connection is closing or closed, unable to send message' )
        return conn.close()
    }
    try
    {
        conn.send( JSON.stringify( message ) )
        log( 'debug', 'Sent message:', message )
    } catch ( e )
    {
        log( 'error', 'Error sending message:', e )
        conn.close()
    }
}

/**
 * Handle incoming WebSocket messages
 * @param {WebSocket} conn - The WebSocket connection
 * @param {object} message - The parsed message object
 */
const handleMessage = ( conn, message ) =>
{
    const { type, topics: messageTopics, topic } = message

    log( 'debug', 'Handling message of type:', type )

    // Check for invalid topics
    if ( messageTopics )
    {
        const invalidTopics = messageTopics.filter( t => !CONFIG.allowedTopics.has( t ) )
        if ( invalidTopics.length > 0 )
        {
            log( 'info', 'Invalid topic(s) detected:', invalidTopics.join( ', ' ) )
            log( 'debug', 'Allowed topic(s):', Array.from( CONFIG.allowedTopics ).join( ', ' ) )
            log( 'info', 'Disconnecting client due to invalid topic(s).' )
            return conn.close()
        }
    }

    switch ( type )
    {
        case 'subscribe':
            messageTopics.forEach( topicName =>
            {
                if ( !topics.has( topicName ) ) topics.set( topicName, new Set() )
                topics.get( topicName ).add( conn )
                conn.subscribedTopics.add( topicName )
                log( 'info', `Client subscribed to topic: ${ topicName }` )
            } )
            break
        case 'unsubscribe':
            messageTopics.forEach( topicName =>
            {
                const topicSet = topics.get( topicName )
                if ( topicSet )
                {
                    topicSet.delete( conn )
                    if ( topicSet.size === 0 ) topics.delete( topicName )
                    conn.subscribedTopics.delete( topicName )
                    log( 'info', `Client unsubscribed from topic: ${ topicName }` )
                }
            } )
            break
        case 'publish':
            const receivers = topics.get( topic )
            if ( receivers )
            {
                message.clients = receivers.size
                receivers.forEach( receiver => send( receiver, message ) )
                log( 'info', `Published message to topic: ${ topic }, receivers: ${ receivers.size }` )
            } else
            {
                log( 'info', `Attempted to publish to non-existent topic: ${ topic }` )
            }
            break
        case 'ping':
            send( conn, { type: 'pong' } )
            log( 'debug', 'Received ping, sent pong' )
            break
        default:
            log( 'info', `Received unknown message type: ${ type }` )
    }
}

/**
 * Handle new WebSocket connections
 * @param {WebSocket} conn - The new WebSocket connection
 */
const onConnection = ( conn ) =>
{
    log( 'info', 'New client connected' )

    // Initialize connection properties
    conn.subscribedTopics = new Set()
    conn.isAlive = true

    // Set up ping interval
    const pingInterval = setInterval( () =>
    {
        if ( !conn.isAlive )
        {
            log( 'info', 'Connection is not alive, terminating' )
            clearInterval( pingInterval )
            return conn.terminate()
        }
        conn.isAlive = false
        conn.ping()
        log( 'debug', 'Ping sent' )
    }, CONFIG.pingTimeout )

    // Handle pong messages
    conn.on( 'pong', () =>
    {
        conn.isAlive = true
        log( 'debug', 'Pong received' )
    } )

    // Handle connection close
    conn.on( 'close', () =>
    {
        conn.subscribedTopics.forEach( topicName =>
        {
            const topicSet = topics.get( topicName )
            if ( topicSet )
            {
                topicSet.delete( conn )
                if ( topicSet.size === 0 ) topics.delete( topicName )
                log( 'debug', `Removed client from topic: ${ topicName }` )
            }
        } )
        clearInterval( pingInterval )
        log( 'info', 'Client fully disconnected' )
    } )

    // Handle incoming messages
    conn.on( 'message', ( message ) =>
    {
        log( 'debug', 'Received message:', message )
        try
        {
            const parsedMessage = JSON.parse( message )
            if ( parsedMessage && parsedMessage.type )
            {
                handleMessage( conn, parsedMessage )
            } else
            {
                log( 'info', 'Received message without type, ignoring' )
            }
        } catch ( e )
        {
            log( 'error', 'Error parsing message:', e )
        }
    } )
}

// Create HTTP server
const server = http.createServer( ( _, res ) =>
{
    res.writeHead( 204 )
    res.end()
} )

// Create WebSocket server
const wss = new WebSocketServer( { noServer: true } )
wss.on( 'connection', onConnection )

// Handle upgrade requests
server.on( 'upgrade', ( request, socket, head ) =>
{
    log( 'debug', 'HTTP upgrade request received' )
    wss.handleUpgrade( request, socket, head, ( ws ) =>
    {
        log( 'info', 'WebSocket connection authenticated' )
        wss.emit( 'connection', ws, request )
    } )
} )

// Start the server
server.listen( CONFIG.port, CONFIG.host, () =>
{
    log( 'notice', 'Welcome to LobeChat WebRTC Signaling server!!!' )
    log( 'notice', 'Developed by @hezhijie0327. Ref: https://github.com/lobehub/y-webrtc-signaling' )
    log( 'notice', 'Server configuration:', CONFIG )
} )
