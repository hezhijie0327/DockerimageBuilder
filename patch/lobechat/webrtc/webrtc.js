#!/usr/bin/env node

import { WebSocketServer } from 'ws'

// Configuration object
const CONFIG = {
    logLevel: process.env.WEBRTC_LOG_LEVEL || 'notice',
    host: process.env.WEBRTC_HOST || '0.0.0.0',
    port: parseInt( process.env.WEBRTC_PORT ) || 3000,
    allowedTopics: new Set( ( process.env.WEBRTC_ALLOWED_TOPICS || '' ).split( ',' ).map( topic => topic.trim() ) ),
    pingTimeout: parseInt( process.env.WEBRTC_PING_TIMEOUT ) || 30000,
}

// Map to store topics and their subscribed connections
const topics = new Map()

/**
 * Logs messages based on the configured log level.
 * @param {string} level - The log level ('debug', 'info', 'notice', 'error', 'none').
 * @param {...any} args - The messages or objects to log.
 */
const logMessage = ( level, ...args ) =>
{
    const levels = [ 'debug', 'info', 'notice', 'error', 'none' ]
    const configLevelIndex = levels.indexOf( CONFIG.logLevel )
    const messageLevelIndex = levels.indexOf( level )

    // Check if the current log level allows logging of the given level
    if ( configLevelIndex < 4 && messageLevelIndex >= configLevelIndex )
    {
        const formattedArgs = args.map( arg =>
        {
            // Stringify objects for better logging
            if ( typeof arg === 'object' && arg !== null )
            {
                try
                {
                    return JSON.stringify( arg, null, 2 )
                } catch ( e )
                {
                    return arg
                }
            }
            return arg
        } )

        // Output the log message
        console.log( `[${ level.toUpperCase() }]`, ...formattedArgs )
    }
}

/**
 * Send a message to a WebSocket connection
 * @param {WebSocket} conn - The WebSocket connection
 * @param {object} message - The message to send
 */
const sendMessage = ( conn, message ) =>
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
        logMessage( 'debug', 'Connection is closing or closed, unable to send message' )
        return conn.close()
    }
    try
    {
        conn.send( JSON.stringify( message ) )
        logMessage( 'debug', 'Sent message:', message )
    } catch ( e )
    {
        logMessage( 'error', 'Error sending message:', e )
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
    logMessage( 'debug', 'Received message:', message )

    const { type, topics: messageTopics, topic } = message

    // Check for invalid topics
    if ( messageTopics )
    {
        const invalidTopics = messageTopics.filter( t => !CONFIG.allowedTopics.has( t ) )
        if ( invalidTopics.length > 0 )
        {
            logMessage( 'info', 'Invalid topic(s) detected:', invalidTopics.join( ', ' ) )
            logMessage( 'debug', 'Allowed topic(s):', Array.from( CONFIG.allowedTopics ).join( ', ' ) )
            logMessage( 'info', 'Disconnecting client due to invalid topic(s).' )
            return conn.close()
        }
    }

    logMessage( 'debug', 'Handling message of type:', type )

    switch ( type )
    {
        case 'ping':
            sendMessage( conn, { type: 'pong' } )
            logMessage( 'debug', 'Received ping, sent pong' )
            break
        case 'publish':
            const receivers = topics.get( topic )
            if ( receivers )
            {
                message.clients = receivers.size
                receivers.forEach( receiver => sendMessage( receiver, message ) )
                logMessage( 'info', `Published message to topic: ${ topic }, receivers: ${ receivers.size }` )
            } else
            {
                logMessage( 'info', `Attempted to publish to non-existent topic: ${ topic }` )
            }
            break
        case 'subscribe':
            messageTopics.forEach( topicName =>
            {
                if ( !topics.has( topicName ) ) topics.set( topicName, new Set() )
                topics.get( topicName ).add( conn )
                conn.subscribedTopics.add( topicName )
                logMessage( 'info', `Client subscribed to topic: ${ topicName }` )
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
                    logMessage( 'info', `Client unsubscribed from topic: ${ topicName }` )
                }
            } )
            break
        default:
            logMessage( 'info', `Received unknown message type: ${ type }` )
    }
}

/**
 * Handle new WebSocket connections
 * @param {WebSocket} conn - The new WebSocket connection
 */
const onConnection = ( conn ) =>
{
    logMessage( 'info', 'New client connected' )

    // Initialize connection properties
    conn.subscribedTopics = new Set()

    // Set up ping/pong
    conn.isAlive = true
    conn.on( 'pong', () =>
    {
        conn.isAlive = true
        logMessage( 'debug', 'Pong received' )
    } )

    // Set up ping interval
    const pingInterval = setInterval( () =>
    {
        if ( !conn.isAlive )
        {
            logMessage( 'info', 'Client connection terminated due to lack of response' )
            clearInterval( pingInterval )
            return conn.terminate()
        }

        conn.isAlive = false
        conn.ping()
        logMessage( 'debug', 'Ping sent' )
    }, CONFIG.pingTimeout )

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
                logMessage( 'debug', `Removed client from topic: ${ topicName }` )
            }
        } )

        clearInterval( pingInterval )
        logMessage( 'info', 'Client(s) fully disconnected' )
    } )

    // Handle incoming messages
    conn.on( 'message', ( message ) =>
    {
        try
        {
            const parsedMessage = JSON.parse( message )
            if ( parsedMessage && parsedMessage.type )
            {
                handleMessage( conn, parsedMessage )
            } else
            {
                logMessage( 'info', 'Received message without type, ignoring' )
            }
        } catch ( e )
        {
            logMessage( 'error', 'Error parsing message:', e )
        }
    } )
}

// Create WebSocket server
const wss = new WebSocketServer( {
    host: CONFIG.host,
    port: CONFIG.port,
} )

// Handle WebSocket connections
wss.on( 'connection', onConnection )

// Handle WebSocket errors
wss.on( 'error', ( error ) =>
{
    logMessage( 'error', 'WebSocket server error:', error )
} )

// Start WebSocket server
wss.on( 'listening', () =>
{
    logMessage( 'notice', 'Welcome to LobeChat WebRTC Signaling server!!!' )
    logMessage( 'notice', 'Developed by @hezhijie0327' )
    logMessage( 'notice', 'Server configuration:', CONFIG )
} )
