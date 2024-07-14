#!/usr/bin/env node

import { WebSocketServer } from 'ws'

// Configuration object
const CONFIG = {
    logging: {
        levelList: [ 'debug', 'info', 'notice', 'error', 'none' ],
        logLevel: process.env.WEBRTC_LOG_LEVEL || 'notice',
    },
    server: {
        host: process.env.WEBRTC_HOST || '0.0.0.0',
        port: parseInt( process.env.WEBRTC_PORT ) || 3000,
    },
    timeouts: {
        ping: parseInt( process.env.WEBRTC_PING_TIMEOUT ) || 30000,
    },
    topics: {
        allowedList: new Set( ( process.env.WEBRTC_ALLOWED_TOPICS || '' ).split( ',' ).filter( Boolean ).map( topic => topic.trim() ) ),
        topicsMap: new Map(),
    },
}

/**
 * Logs messages based on the configured log level.
 * @param {string} level - The log level.
 * @param {...any} args - The messages or objects to log.
 */
const generateSyslog = ( level, ...args ) =>
{
    const { logLevel, levelList } = CONFIG.logging

    // Ensure the provided log level is valid
    if ( !levelList.includes( level ) )
    {
        throw new Error( `Invalid log level: ${ level }. Allowed levels are ${ levelList.join( ', ' ) }` )
    }

    const logLevelIndex = levelList.indexOf( logLevel )
    const messageLevelIndex = levelList.indexOf( level )

    // Check if the current log level allows logging of the given level
    if ( logLevelIndex <= messageLevelIndex )
    {
        const formattedArgs = args.map( arg =>
        {
            // Stringify objects for better logging with sorted keys
            if ( typeof arg === 'object' && arg !== null )
            {
                try
                {
                    const sortedArg = Object.keys( arg ).sort().reduce( ( sorted, key ) =>
                    {
                        sorted[ key ] = arg[ key ]
                        return sorted
                    }, {} )
                    return JSON.stringify( sortedArg, ( key, value ) =>
                    {
                        if ( value instanceof Set )
                        {
                            return Array.from( value )
                        }
                        return value
                    }, 2 )
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
    if ( conn.readyState > 1 )
    {
        generateSyslog( 'debug', 'Connection is closing or closed, unable to send message' )
        return conn.close()
    }
    try
    {
        conn.send( JSON.stringify( message ) )
        generateSyslog( 'debug', 'Sent message:', message )
    } catch ( e )
    {
        generateSyslog( 'error', 'Error sending message:', e )
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
    generateSyslog( 'debug', 'Received message:', message )

    const { type, topics: messageTopics, topic } = message

    // Check for invalid topics
    if ( messageTopics && CONFIG.topics.allowedList.size > 0 )
    {
        const invalidTopics = messageTopics.filter( t => !CONFIG.topics.allowedList.has( t ) )
        if ( invalidTopics.length > 0 )
        {
            generateSyslog( 'info', 'Invalid topic(s) detected:', invalidTopics.join( ', ' ) )
            generateSyslog( 'debug', 'Allowed topic(s):', Array.from( CONFIG.topics.allowedList ).join( ', ' ) )
            generateSyslog( 'info', 'Disconnecting client due to invalid topic(s).' )
            return conn.close()
        }
    }

    generateSyslog( 'debug', 'Handling message of type:', type )

    switch ( type )
    {
        case 'ping':
            sendMessage( conn, { type: 'pong' } )
            generateSyslog( 'debug', 'Received ping, sent pong' )
            break
        case 'publish':
            const receivers = CONFIG.topics.topicsMap.get( topic )
            if ( receivers )
            {
                message.clients = receivers.size
                receivers.forEach( receiver => sendMessage( receiver, message ) )
                generateSyslog( 'info', `Published message to topic: ${ topic }, receivers: ${ receivers.size }` )
            }
            break
        case 'subscribe':
            messageTopics.forEach( topicName =>
            {
                if ( !CONFIG.topics.topicsMap.has( topicName ) )
                {
                    CONFIG.topics.topicsMap.set( topicName, new Set() )
                }
                CONFIG.topics.topicsMap.get( topicName ).add( conn )
                conn.subscribedTopics.add( topicName )
                generateSyslog( 'info', `Client subscribed to topic: ${ topicName }` )
            } )
            break
        case 'unsubscribe':
            messageTopics.forEach( topicName =>
            {
                const topicSet = CONFIG.topics.topicsMap.get( topicName )
                if ( topicSet )
                {
                    topicSet.delete( conn )
                    if ( topicSet.size === 0 )
                    {
                        CONFIG.topics.topicsMap.delete( topicName )
                    }
                    conn.subscribedTopics.delete( topicName )
                    generateSyslog( 'info', `Client unsubscribed from topic: ${ topicName }` )
                }
            } )
            break
        default:
            generateSyslog( 'info', `Received unknown message type: ${ type }` )
    }
}

/**
 * Handle new WebSocket connections
 * @param {WebSocket} conn - The new WebSocket connection
 * @param {http.IncomingMessage} req - The request object
 */
const handleWebSocketConnection = ( conn, req ) =>
{
    const clientInfo = {
        ipAddress: req.headers[ 'CF-Connecting-IP' ] || req.headers[ 'x-forwarded-for' ] || 'Unknown',
        userAgent: req.headers[ 'user-agent' ] || 'Unknown'
    }

    generateSyslog( 'info', 'Client connected:', clientInfo )

    // Initialize connection properties
    conn.isAlive = true
    conn.subscribedTopics = new Set()

    // Set up ping interval
    const pingInterval = setInterval( () =>
    {
        if ( !conn.isAlive )
        {
            generateSyslog( 'info', 'Client connection terminated due to lack of response' )
            clearInterval( pingInterval )
            return conn.terminate()
        }

        conn.isAlive = false
        conn.ping()
        generateSyslog( 'debug', 'Ping sent' )
    }, CONFIG.timeouts.ping )

    // Handle connection close
    conn.on( 'close', () =>
    {
        conn.subscribedTopics.forEach( topicName =>
        {
            const topicSet = CONFIG.topics.topicsMap.get( topicName )
            if ( topicSet )
            {
                topicSet.delete( conn )
                if ( topicSet.size === 0 )
                {
                    CONFIG.topics.topicsMap.delete( topicName )
                }
                generateSyslog( 'debug', `Removed client from topic: ${ topicName }` )
            }
        } )

        clearInterval( pingInterval )
        generateSyslog( 'info', 'Client disconnected:', clientInfo )
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
                generateSyslog( 'info', 'Received message without type, ignoring' )
            }
        } catch ( e )
        {
            generateSyslog( 'error', 'Error parsing message:', e )
        }
    } )

    // Handle pong responses
    conn.on( 'pong', () =>
    {
        conn.isAlive = true
        generateSyslog( 'debug', 'Pong received' )
    } )
}

// Create WebSocket server
const wss = new WebSocketServer( {
    host: CONFIG.server.host,
    port: CONFIG.server.port,
} )

// Handle WebSocket connections
wss.on( 'connection', ( conn, req ) =>
{
    handleWebSocketConnection( conn, req )
} )

// Handle WebSocket errors
wss.on( 'error', ( error ) =>
{
    generateSyslog( 'error', 'WebSocket server error:', error )
} )

// Start WebSocket server
wss.on( 'listening', () =>
{
    generateSyslog( 'notice', 'Welcome to LobeChat WebRTC Signaling server!!!' )
    generateSyslog( 'notice', 'Developed by @hezhijie0327' )
    generateSyslog( 'notice', 'Server configuration:', CONFIG )
} )
