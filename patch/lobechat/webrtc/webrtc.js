#!/usr/bin/env node

import { WebSocketServer } from 'ws'

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
        handleSyslog( 'debug', 'Connection is closing or closed, unable to send message' )
        return conn.close()
    }
    try
    {
        conn.send( JSON.stringify( message ) )
        handleSyslog( 'debug', 'Sent message:', message )
    } catch ( e )
    {
        handleSyslog( 'error', 'Error sending message:', e )
        conn.close()
    }
}

/**
 * Handle new WebSocket connections
 * @param {WebSocket} conn - The new WebSocket connection
 */
const handleConnection = ( conn ) =>
{
    handleSyslog( 'info', 'New client connected' )

    // Initialize connection properties
    conn.subscribedTopics = new Set()

    // Set up ping/pong
    conn.isAlive = true
    conn.on( 'pong', () =>
    {
        conn.isAlive = true
        handleSyslog( 'debug', 'Pong received' )
    } )

    // Set up ping interval
    const pingInterval = setInterval( () =>
    {
        if ( !conn.isAlive )
        {
            handleSyslog( 'info', 'Client connection terminated due to lack of response' )
            clearInterval( pingInterval )
            return conn.terminate()
        }

        conn.isAlive = false
        conn.ping()
        handleSyslog( 'debug', 'Ping sent' )
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
                handleSyslog( 'debug', `Removed client from topic: ${ topicName }` )
            }
        } )

        clearInterval( pingInterval )
        handleSyslog( 'info', 'Client(s) fully disconnected' )
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
                handleSyslog( 'info', 'Received message without type, ignoring' )
            }
        } catch ( e )
        {
            handleSyslog( 'error', 'Error parsing message:', e )
        }
    } )
}

/**
 * Handle incoming WebSocket messages
 * @param {WebSocket} conn - The WebSocket connection
 * @param {object} message - The parsed message object
 */
const handleMessage = ( conn, message ) =>
{
    handleSyslog( 'debug', 'Received message:', message )

    const { type, topics: messageTopics, topic } = message

    // Check for invalid topics
    if ( messageTopics )
    {
        const deniedTopics = messageTopics.filter( t => CONFIG.denied.has( t ) )
        const invalidTopics = messageTopics.filter( t => !CONFIG.allowed.has( t ) )

        if ( deniedTopics.length > 0 )
        {
            handleSyslog( 'info', 'Denied topic(s) detected:', deniedTopics.join( ', ' ) )
            handleSyslog( 'debug', 'Denied topic(s):', Array.from( CONFIG.denied ).join( ', ' ) )
            handleSyslog( 'info', 'Disconnecting client due to denied topic(s).' )
            return conn.close()
        }

        if ( invalidTopics.length > 0 )
        {
            handleSyslog( 'info', 'Invalid topic(s) detected:', invalidTopics.join( ', ' ) )
            handleSyslog( 'debug', 'Allowed topic(s):', Array.from( CONFIG.allowed ).join( ', ' ) )
            handleSyslog( 'info', 'Disconnecting client due to invalid topic(s).' )
            return conn.close()
        }
    }

    handleSyslog( 'debug', 'Handling message of type:', type )

    switch ( type )
    {
        case 'ping':
            sendMessage( conn, { type: 'pong' } )
            handleSyslog( 'debug', 'Received ping, sent pong' )
            break
        case 'publish':
            const receivers = topics.get( topic )
            if ( receivers )
            {
                message.clients = receivers.size
                receivers.forEach( receiver => sendMessage( receiver, message ) )
                handleSyslog( 'info', `Published message to topic: ${ topic }, receivers: ${ receivers.size }` )
            } else
            {
                handleSyslog( 'info', `Attempted to publish to non-existent topic: ${ topic }` )
            }
            break
        case 'subscribe':
            messageTopics.forEach( topicName =>
            {
                if ( !topics.has( topicName ) )
                {
                    topics.set( topicName, new Set() )
                }
                topics.get( topicName ).add( conn )
                conn.subscribedTopics.add( topicName )
                handleSyslog( 'info', `Client subscribed to topic: ${ topicName }` )
            } )
            break
        case 'unsubscribe':
            messageTopics.forEach( topicName =>
            {
                const topicSet = topics.get( topicName )
                if ( topicSet )
                {
                    topicSet.delete( conn )
                    if ( topicSet.size === 0 )
                    {
                        topics.delete( topicName )
                    }
                    conn.subscribedTopics.delete( topicName )
                    handleSyslog( 'info', `Client unsubscribed from topic: ${ topicName }` )
                }
            } )
            break
        default:
            handleSyslog( 'info', `Received unknown message type: ${ type }` )
    }
}

/**
 * Logs messages based on the configured log level.
 * @param {string} level - The log level ('debug', 'info', 'notice', 'error', 'none').
 * @param {...any} args - The messages or objects to log.
 */
const handleSyslog = ( level, ...args ) =>
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
 * Parse the merged topics environment variable into allowed and denied topics
 * @param {string} topics - The merged topics string with + for allowed and - for denied topics
 * @returns {{ allowed: Set<string>, denied: Set<string> }} - An object containing sets of allowed and denied topics
 */
const parseTopics = ( topics ) =>
{
    const allowed = new Set()
    const denied = new Set()

    topics.split( ',' ).forEach( topic =>
    {
        topic = topic.trim()
        if ( topic.startsWith( '+' ) )
        {
            allowed.add( topic.slice( 1 ) )
        } else if ( topic.startsWith( '-' ) )
        {
            denied.add( topic.slice( 1 ) )
        }
    } )

    return { allowed, denied }
}

// Server Configuration
const CONFIG = {
    logLevel: process.env.WEBRTC_LOG_LEVEL || 'notice',
    host: process.env.WEBRTC_HOST || '0.0.0.0',
    port: parseInt( process.env.WEBRTC_PORT ) || 3000,
    ...parseTopics( process.env.WEBRTC_TOPICS_LIST || '' ),
    pingTimeout: parseInt( process.env.WEBRTC_PING_TIMEOUT ) || 30000,
}

// Map to store topics and their subscribed connections
const topics = new Map()

// Create WebSocket server
const wss = new WebSocketServer( {
    host: CONFIG.host,
    port: CONFIG.port,
} )

// Handle WebSocket connections
wss.on( 'connection', handleConnection )

// Handle WebSocket errors
wss.on( 'error', ( error ) =>
{
    handleSyslog( 'error', 'WebSocket server error:', error )
} )

// Start WebSocket server
wss.on( 'listening', () =>
{
    handleSyslog( 'notice', 'Welcome to LobeChat WebRTC Signaling server!!!' )
    handleSyslog( 'notice', 'Developed by @hezhijie0327' )
    handleSyslog( 'notice', 'Server configuration:', CONFIG )
} )
