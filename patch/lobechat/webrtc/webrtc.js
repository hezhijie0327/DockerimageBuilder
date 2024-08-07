/**
 * LobeChat WebRTC Signaling Server
 */
const WebSocket = require( 'ws' )

/**
 * Configuration object for the WebRTC Signaling Server
 * This object contains all the necessary settings for the server,
 * including logging levels, server details, timeouts, and topic management.
 */
const CONFIG = {
    logging: {
        // Allowed log levels in order of verbosity
        allowedLevels: [ 'debug', 'info', 'notice', 'error', 'none' ],
        // Current log level, can be set via environment variable or defaults to 'notice'
        logLevel: process.env.WEBRTC_LOG_LEVEL || 'notice',
    },
    server: {
        // Enable or disable the server, defaults to false
        enable: process.env.ENABLE_WEBRTC_SIGNALING_SERVER || false,
        // Host to bind the server to, defaults to all interfaces
        host: process.env.WEBRTC_HOST || '0.0.0.0',
        // Port to run the server on, defaults to 3000
        port: Number( process.env.WEBRTC_PORT ) || 3000,
    },
    timeouts: {
        // Interval for ping messages to keep connections alive (in milliseconds)
        ping: Number( process.env.WEBRTC_PING_TIMEOUT ) || 30000,
    },
    topics: {
        // Set of allowed topics, populated from environment variable
        allowedList: new Set( ( process.env.WEBRTC_ALLOWED_TOPICS || '' ).split( ',' ).filter( Boolean ).map( topic => topic.trim() ) ),
        // Map to store active topics and their subscribers
        topicsMap: new Map(),
    },
}

/**
 * Logs messages based on the configured log level.
 * This function provides a flexible logging mechanism that respects the current log level
 * and formats complex objects for better readability.
 *
 * @param {string} level - The log level ('debug', 'info', 'notice', 'error', 'none').
 * @param {...any} args - The messages or objects to log.
 * @throws {Error} If an invalid log level is provided.
 */
const logMessage = ( level, ...args ) =>
{
    const { allowedLevels, logLevel } = CONFIG.logging

    // Ensure the provided log level is valid
    if ( !allowedLevels.includes( level ) )
    {
        throw new Error( `Invalid log level: ${ level }. Allowed levels are ${ allowedLevels.join( ', ' ) }` )
    }

    const logLevelIndex = allowedLevels.indexOf( logLevel )
    const messageLevelIndex = allowedLevels.indexOf( level )

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
                    // Sort object keys for consistent output
                    const sortedArg = Object.keys( arg ).sort().reduce( ( sorted, key ) =>
                    {
                        sorted[ key ] = arg[ key ]

                        return sorted
                    }, {} )
                    // Convert Sets to Arrays for proper stringification
                    return JSON.stringify( sortedArg, ( key, value ) =>
                    {
                        if ( value instanceof Set )
                        {
                            return Array.from( value )
                        } else
                        {
                            return value
                        }
                    }, 2 )
                } catch ( e )
                {
                    return arg
                }
            } else
            {
                return arg
            }
        } )

        // Output the log message
        console.log( `[${ level.toUpperCase() }]`, ...formattedArgs )
    }
}

/**
 * Handle new WebSocket connections
 * This is the main function that manages the lifecycle of each WebSocket connection,
 * including message handling, ping/pong for keep-alive, and cleanup on disconnection.
 *
 * @param {any} conn - The new WebSocket connection object.
 * @param {any} req - The HTTP request that initiated the WebSocket connection.
 */
const handleWebSocketConnection = ( conn, req ) =>
{
    // Extract and log basic client information
    const clientInfo = {
        ipAddress: req.headers[ 'x-forwarded-for' ] || 'Unknown',
        userAgent: req.headers[ 'user-agent' ] || 'Unknown'
    }

    logMessage( 'info', 'New client connected:', clientInfo )

    // Initialize connection-specific variables
    const subscribedTopics = new Set()

    let isClosed = false
    let pongReceived = true

    // Set up ping interval to keep connection alive
    const pingInterval = setInterval( () =>
    {
        if ( !pongReceived )
        {
            // Close the connection if no pong was received since the last ping
            conn.close()

            logMessage( 'info', 'Connection closed due to ping timeout:', clientInfo )

            clearInterval( pingInterval )
        } else
        {
            // Send a new ping
            pongReceived = false

            try
            {
                conn.ping()

                logMessage( 'debug', 'Ping sent:', clientInfo )
            } catch ( e )
            {
                conn.close()

                logMessage( 'error', 'Connection closed due to ping error:', e )
            }
        }
    }, CONFIG.timeouts.ping )

    // Handle connection close
    conn.on( 'close', () =>
    {
        // Clean up subscriptions when a client disconnects
        subscribedTopics.forEach( topicName =>
        {
            const topicSet = CONFIG.topics.topicsMap.get( topicName ) || new Set()

            topicSet.delete( conn )

            if ( topicSet.size === 0 )
            {
                CONFIG.topics.topicsMap.delete( topicName )
            }

            logMessage( 'debug', `Client unsubscribed from topic: ${ topicName }` )
        } )

        subscribedTopics.clear()

        logMessage( 'debug', 'Client unsubscribed from all topics' )

        isClosed = true

        logMessage( 'info', 'Client disconnected:', clientInfo )
    } )

    // Handle incoming messages
    conn.on( 'message', ( message ) =>
    {
        // Parse the message if it's a string or Buffer
        if ( typeof message === 'string' || message instanceof Buffer )
        {
            message = JSON.parse( message )
        }

        if ( message && message.type && !isClosed )
        {
            logMessage( 'debug', 'Received message:', message )

            // Validate topics if a whitelist is defined
            if ( message.topics && CONFIG.topics.allowedList.size > 0 )
            {
                const invalidTopics = message.topics.filter( t => !CONFIG.topics.allowedList.has( t ) )

                if ( invalidTopics.length > 0 )
                {
                    logMessage( 'debug', 'Invalid topic(s) detected:', invalidTopics.join( ', ' ) )
                    logMessage( 'debug', 'Allowed topic(s):', Array.from( CONFIG.topics.allowedList ).join( ', ' ) )

                    // Close the connection if invalid topics are detected
                    conn.close()

                    logMessage( 'info', 'Connection closed due to invalid topic(s):', clientInfo )
                }
            }

            // Process the message based on its type
            switch ( message.type )
            {
                case 'ping':
                    conn.pong()

                    logMessage( 'debug', 'Ping received, pong sent:', clientInfo )

                    break

                case 'publish':
                    // Handle message publication to a topic
                    if ( message.topic )
                    {
                        const receivers = CONFIG.topics.topicsMap.get( message.topic )

                        if ( receivers )
                        {
                            message.clients = receivers.size

                            receivers.forEach( receiver =>
                            {
                                // Check if the connection is closing or closed
                                if ( receiver.readyState <= 1 )
                                {
                                    try
                                    {
                                        // Serialize and send the message
                                        receiver.send( JSON.stringify( message ) )

                                        logMessage( 'debug', 'Message sent to receiver:', message )
                                    } catch ( e )
                                    {
                                        // Close the connection if an error occurs during sending
                                        receiver.close()

                                        logMessage( 'error', 'Error sending message to receiver:', e )
                                    }
                                } else
                                {
                                    receiver.close()

                                    logMessage( 'debug', 'Receiver connection closing or closed, message not sent' )
                                }
                            } )

                            logMessage( 'debug', `Message published to topic: ${ message.topic }, receivers: ${ receivers.size }` )
                        } else
                        {
                            logMessage( 'debug', `No receivers found for topic: ${ message.topic }` )
                        }
                    } else
                    {
                        logMessage( 'debug', 'Publish message missing topic' )
                    }

                    break

                case 'subscribe':
                    // Handle topic subscription
                    ( message.topics || [] ).forEach( topicName =>
                    {
                        if ( typeof topicName === 'string' )
                        {
                            const topicSet = ( () =>
                            {
                                const map = CONFIG.topics.topicsMap
                                const key = topicName

                                if ( !map.has( key ) )
                                {
                                    const value = new Set()

                                    map.set( key, value )

                                    return value
                                } else
                                {
                                    return map.get( key )
                                }
                            } )()

                            topicSet.add( conn )

                            subscribedTopics.add( topicName )

                            logMessage( 'debug', `Client subscribed to topic: ${ topicName }` )
                        } else
                        {
                            logMessage( 'debug', 'Invalid topic name in subscription:', topicName )
                        }
                    } )

                    break

                case 'unsubscribe':
                    // Handle topic unsubscription
                    ( message.topics || [] ).forEach( topicName =>
                    {
                        const topicSet = CONFIG.topics.topicsMap.get( topicName )

                        if ( topicSet )
                        {
                            topicSet.delete( conn )

                            logMessage( 'debug', `Client unsubscribed from topic: ${ topicName }` )
                        } else
                        {
                            logMessage( 'debug', `Client not subscribed to topic: ${ topicName }` )
                        }
                    } )

                    break

                default:
                    logMessage( 'debug', `Unknown message type received: ${ message.type }` )
            }
        }
    } )

    // Handle pong responses
    conn.on( 'pong', () =>
    {
        pongReceived = true

        logMessage( 'debug', 'Pong received:', clientInfo )
    } )
}

if ( CONFIG.server.enable )
{
    logMessage( 'info', 'LobeChat WebRTC Signaling Server function flag has been enabled' )

    // Create WebSocket server
    const wss = new WebSocket.Server( {
        host: CONFIG.server.host,
        port: CONFIG.server.port,
    } )

    // Handle new WebSocket connections
    wss.on( 'connection', ( conn, req ) =>
    {
        handleWebSocketConnection( conn, req )
    } )

    // Handle WebSocket server errors
    wss.on( 'error', ( error ) =>
    {
        logMessage( 'error', 'WebSocket server error:', error )
    } )

    // Log server start and configuration
    wss.on( 'listening', () =>
    {
        logMessage( 'notice', 'LobeChat WebRTC Signaling Server started' )
        logMessage( 'notice', 'Server configuration:', CONFIG )
    } )
} else
{
    logMessage( 'info', 'LobeChat WebRTC Signaling Server function flag has been disabled' )
}
