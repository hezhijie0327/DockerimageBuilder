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
        port: Number( process.env.WEBRTC_PORT ) || 3000,
    },
    timeouts: {
        ping: Number( process.env.WEBRTC_PING_TIMEOUT ) || 30000,
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
const printSyslog = ( level, ...args ) =>
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
        conn.close()

        printSyslog( 'debug', 'Connection is closing or closed, unable to send message' )
    }
    try
    {
        conn.send( JSON.stringify( message ) )

        printSyslog( 'debug', 'Sent message:', message )
    } catch ( e )
    {
        conn.close()

        printSyslog( 'error', 'Error sending message:', e )
    }
}

/**
 * Handle new WebSocket connections
 * @param {any} conn - The new WebSocket connection
 * @param {any} req - The request object
 */
const handleWebSocketConnection = ( conn, req ) =>
{
    // Get basic client infomation from headers
    const clientInfo = {
        ipAddress: req.headers[ 'CF-Connecting-IP' ] || req.headers[ 'x-forwarded-for' ] || 'Unknown',
        userAgent: req.headers[ 'user-agent' ] || 'Unknown'
    }

    printSyslog( 'info', 'Client connected:', clientInfo )

    // Initialize connection properties
    const subscribedTopics = new Set()

    let isClosed = false
    let pongReceived = true

    // Set up ping interval
    const pingInterval = setInterval( () =>
    {
        if ( !pongReceived )
        {
            conn.close()

            printSyslog( 'info', 'Client connection terminated due to lack of response' )

            clearInterval( pingInterval )
        } else
        {
            pongReceived = false

            try
            {
                conn.ping()

                printSyslog( 'debug', 'Ping sent' )
            } catch ( e )
            {
                conn.close()

                printSyslog( 'error', 'Error sending ping:', e )
            }
        }
    }, CONFIG.timeouts.ping )

    // Handle connection close
    conn.on( 'close', () =>
    {
        subscribedTopics.forEach( topicName =>
        {
            const topicSet = CONFIG.topics.topicsMap.get( topicName ) || new Set()

            topicSet.delete( conn )

            if ( topicSet.size === 0 )
            {
                CONFIG.topics.topicsMap.delete( topicName )
            }
        } )

        subscribedTopics.clear()

        isClosed = true

        printSyslog( 'info', 'Client disconnected:', clientInfo )
    } )

    // Handle incoming messages
    conn.on( 'message', ( message ) =>
    {
        if ( typeof message === 'string' || message instanceof Buffer )
        {
            message = JSON.parse( message )
        }
        if ( message && message.type && !isClosed )
        {
            printSyslog( 'debug', 'Received message:', message )

            // Check for invalid topics
            if ( message.topics && CONFIG.topics.allowedList.size > 0 )
            {
                const invalidTopics = message.topics.filter( t => !CONFIG.topics.allowedList.has( t ) )

                if ( invalidTopics.length > 0 )
                {
                    printSyslog( 'info', 'Invalid topic(s) detected:', invalidTopics.join( ', ' ) )

                    printSyslog( 'debug', 'Allowed topic(s):', Array.from( CONFIG.topics.allowedList ).join( ', ' ) )

                    conn.close()

                    printSyslog( 'info', 'Disconnected client due to invalid topic(s).' )
                }
            }

            printSyslog( 'debug', 'Handling message of type:', message.type )

            switch ( message.type )
            {
                case 'ping':
                    sendMessage( conn, { type: 'pong' } )

                    printSyslog( 'debug', 'Received ping, sent pong' )
                    break
                case 'publish':
                    if ( message.topic )
                    {
                        const receivers = CONFIG.topics.topicsMap.get( message.topic )

                        if ( receivers )
                        {
                            message.clients = receivers.size
                            receivers.forEach( receiver => sendMessage( receiver, message ) )

                            printSyslog( 'info', `Published message to topic: ${ message.topic }, receivers: ${ receivers.size }` )
                        }
                    }
                    break
                case 'subscribe':
                    ( message.topics || [] ).forEach( topicName =>
                    {
                        if ( typeof topicName === 'string' )
                        {
                            const topicSet = CONFIG.topics.topicsMap.get( topicName ) || new Set()

                            topicSet.add( conn )

                            subscribedTopics.add( topicName )

                            printSyslog( 'info', `Client subscribed to topic: ${ topicName }` )
                        }
                    } )
                    break
                case 'unsubscribe':
                    ( message.topics || [] ).forEach( topicName =>
                    {
                        const topicSet = CONFIG.topics.topicsMap.get( topicName )

                        if ( topicSet )
                        {
                            topicSet.delete( conn )

                            printSyslog( 'info', `Client unsubscribed from topic: ${ topicName }` )
                        }
                    } )
                    break
                default:
                    printSyslog( 'info', `Received unknown message type: ${ message.type }` )
            }
        }
    } )

    // Handle pong responses
    conn.on( 'pong', () =>
    {
        pongReceived = true

        printSyslog( 'debug', 'Pong received' )
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
    printSyslog( 'error', 'WebSocket server error:', error )
} )

// Start WebSocket server
wss.on( 'listening', () =>
{
    printSyslog( 'notice', 'Welcome to LobeChat WebRTC Signaling server!!!' )
    printSyslog( 'notice', 'Developed by @hezhijie0327' )
    printSyslog( 'notice', 'Server configuration:', CONFIG )
} )
