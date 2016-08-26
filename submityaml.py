#!/usr/bin/python
import argparse
import os.path
import sys
import time
import xmlrpclib
import urllib2
import yaml

SLEEP = 1
__version__ = 0.5


def is_valid_file(parser, arg, flag):
    if not os.path.exists(arg):
        parser.error("The file %s does not exist!" % arg)
    else:
        return open(arg, flag)  # return an open file handle


def setup_args_parser():
    """Setup the argument parsing.

    :return The parsed arguments.
    """
    description = "Submit job file"
    parser = argparse.ArgumentParser(version=__version__, description=description)
    parser.add_argument("yamlfiles", help="specify target job files", nargs = '*', metavar="FILE",
                   type=lambda x: is_valid_file(parser, x, 'r'))
    parser.add_argument("-d", "--debug", action="store_true", help="Display verbose debug details")
    parser.add_argument("-p", "--poll", action="store_true", help="poll job status until job completes")
    parser.add_argument("-k", "--apikey", default="apikey.txt", help="File containing the LAVA api key")
    parser.add_argument("--port", default="80", help="LAVA/Apache default port number")

    return parser.parse_args()


def loadConfiguration():
    global args
    args = setup_args_parser()


def loadJobs(server_str):
    """loadJobs - read the YAML job files and fix it up for future submission
    """
    jobs = []
    for yaml in args.yamlfiles:
	jobs.append(yaml.read())
    return jobs


def submitJobs(jobs, server):
    """submitJobs - XMLRPC call to submit YAML job files

       returns list ofjobids of the submitted jobs
    """
    jobids = []
    # When making the call to submit_job, you have to send a string
    for job in jobs:
        jobids.append(server.scheduler.submit_job(job))
    return jobids


def gettestResult(jobid):
    url = 'http://lava/results/%s/yaml' % jobid
    response = urllib2.urlopen(url)
    raw = response.read()
    results = yaml.load(raw)
    with open('results.txt', 'a') as r:
        for result in results:
            if result['suite'] != 'lava':
                output = '%s : %s : %s' % (result['suite'], result['name'], result['result'])
                r.write(output + '\n')
                print output


def monitorJobs(jobids, server, server_str):
    """monitorJobs - added to poll for jobs to complete

    """
    if args.poll:
        sys.stdout.write("Job polling enabled\n")
        run = True
        while run:
                if len(jobids) == 0:
                    run = False
		for job in jobids:
			status = server.scheduler.job_status(job)
			if status['job_status'] == 'Complete':
		            print 'Job %s Completed' % job
			    gettestResult(job)
			    jobids.pop(jobids.index(job))
			elif status['job_status'] == 'Canceled':
			    print 'Job %s Canceled' % job
			    jobids.pop(jobids.index(job))
			elif status['job_status'] == 'Submitted':
			    sys.stdout.write("Job %s Submitted\n" % job)
			    sys.stdout.flush()
			elif status['job_status'] == 'Running':
			    sys.stdout.write("Job %s Running\n" % job)
			    sys.stdout.flush()
			else:
			    print "unknown status"
			    jobids.pop(jobids.index(job))
			time.sleep(SLEEP) 


def process():
    print "Submitting test jobs to LAVA server"
    loadConfiguration()
    user = "admin"
    with open(args.apikey) as f:
        line = f.readline()
        apikey = line.rstrip('\n')

    server_str = 'http://lava' + ":" + args.port
    xmlrpc_str = 'http://' + user + ":" + apikey + "@lava" + ":" + args.port + '/RPC2/'
    server = xmlrpclib.ServerProxy(xmlrpc_str)
    server.system.listMethods()

    jobs = loadJobs(server_str)

    jobids = submitJobs(jobs, server)

    monitorJobs(jobids, server, server_str)


if __name__ == '__main__':
    process()
