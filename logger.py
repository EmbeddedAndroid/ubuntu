import zmq
import argparse

__version__ = 1.0

def logger(broker, port, id, msg_type, msg_status, message):
    context = zmq.Context()
    zmq_socket = context.socket(zmq.PUSH)
    uri = 'tcp://%s:%s' % (broker, port)
    zmq_socket.connect(uri)
    message = { 'type': msg_type, 'id': id, 'status': msg_status, 'message': message }
    zmq_socket.send_json(message)

def log():
    description = 'Simple ZMQ Socket Logger'
    parser = argparse.ArgumentParser(version=__version__, description=description)
    parser.add_argument('-m', '--message', help='Message to send', required=True)
    parser.add_argument('-i', '--id', help='Unique ID', required=True)
    parser.add_argument('-t', '--type', help='Message Type', required=True)
    parser.add_argument('-s', '--status', help='Message Status', required=True)
    parser.add_argument('-b', '--broker', help='Message broker', required=True)
    parser.add_argument('-p', '--port', help='Port for message receiver', required=True)
    args = parser.parse_args()
    logger(args.broker, args.port, args.id, args.type, args.status, args.message)

if __name__ == '__main__':
    log()

