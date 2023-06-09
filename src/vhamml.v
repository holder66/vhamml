// cli.v
module main

import hamml
import os
import os.cmdline as oscmdline
import time
import math
// import runtime

// the command line interface app for the holder66.vhamml ML library.
// In a terminal, type:
// `v run . --help`
// ```sh
// Usage: v run . [command] [flags] datafile
// Commands: analyze | append | cross | display | examples | explore
// | make | orange |
//           query | rank | validate | verify
// Flags and options:
// -a --attributes, can be one, two, or 3 integers; a single integer will
//    be used by make_classifier to produce a classifier with that number
//    of attributes. More than one integer will be used by
//    explore to provide a range and an interval.
// -b --bins, can be one, two, or 3 integers; a single integer for one bin
//    value to be used for all attributes; two integers for a range of bin
//    values; a third integer specifies an interval for the range (note that
//    the binning range is from the upper to the lower value);
//    note: when doing an explore, the first integer specifies the lower
//    limit for the number of bins, and the second gives the upper value
//    for the explore range. Example: explore -b 3,6 would first use 3 - 3,
//    then 3 - 4, then 3 - 5, and finally 3 - 6 for the binning ranges.
//    If the uniform flag is true, then a single integer specifies
//    the number of bins for all continuous attributes; two integers for a
//    range of uniform bin values for the explore command; a third integer
//    for the interval to be used over the explore range;
// -bp, --balanced-prevalences, multiply the number of instances for classes
//    with low prevalence, to more closely balance prevalences;
// -c --concurrent, permit parallel processing to use multiple cores;
// -e --expanded, expanded results on the console;
// -f --folds, default is leave-one-out;
// -g --graph, displays a plot;
// -h --help,
// -k --classifier, followed by the path to a file for a saved Classifier
// -m --multiple, classify using more than one trained classifier, followed by
//    the path to a json file with parameters to generate each classifier;
// -ma when multiple classifiers are used, stop classifying when matches
//    have been found for all classifiers;
// -mc when multiple classifiers are used, combine the possible hamming
//    distances for each classifier into a single list;
// -m# followed by a list of which classifiers to apply in a multiple classi-
//	  fication run (zero-indexed); also used to specify which classifiers to
//    append to a settings file;
// -ms append the settings to a file (path follows flag) for use in multiple
//    classification (with -m#). When used with 'explore', the settings for
//    cases identified in the analytics are appended;
// -o --output, followed by the path to a file in which a classifier, a
//    result, instances used for validation, or a query instance will be
//    stored;
// -p --purge, removes instances which after binning are duplicates
// -r --reps, number of repetitions; if > 1, a random selection of
// 	instances to be included in each fold will be applied
// -s --show, output results to the console;
// -t --test, followed by the path to the datafile to be verified or validated;
// -u --uniform, specifies if uniform binning is to be used for the explore
//    command (note: to obtain uniform binning with verify, validate, query, or
//    or cross-validate, specify the same value for binning, eg -b 4,4)
// -v --verbose
// -w --weight, when classifying, weight the nearest neighbour counts by class prevalences;
// -wr when ranking attributes, weight contributions by class prevalences;
// -x --exclude, do not take into account missing values when ranking attributes;
// ```
fn main() {
	sw := time.new_stopwatch()
	// get the command line string and use it to create an Options struct
	// println('nr_cpus: $runtime.nr_cpus() nr_jobs: $runtime.nr_jobs()')
	mut opts := get_options(os.args[1..])

	if opts.help_flag {
		println(show_help(opts))
	} else {
		command := opts.command
		match command {
			'analyze' { analyze(mut opts) }
			'append' { do_append(mut opts)? }
			'cross' { cross(mut opts) }
			'display' { do_display(opts) }
			// 'examples' { examples()! }
			'explore' { do_explore(mut opts) }
			'make' { make(mut opts)? }
			'orange' { orange() }
			'query' { do_query(mut opts)? }
			'rank' { rank(mut opts) }
			'validate' { do_validate(mut opts)? }
			'verify' { do_verify(mut opts)? }
			else { println('unrecognized command') }
		}
	}
	mut duration := sw.elapsed()
	// println('duration: $duration')
	println('processing time: ${int(duration.hours())} hrs ${int(math.fmod(duration.minutes(),
		60))} min ${math.fmod(duration.seconds(), 60):6.3f} sec')
}

// get_options fills an Options struct with values from the command line
fn get_options(args []string) hamml.Options {
	mut opts := hamml.Options{
		args: args
	}
	if (flag(args, ['-h', '--help', 'help']) && args.len == 2) || args.len <= 1 {
		opts.help_flag = true
	}
	opts.non_options = oscmdline.only_non_options(args)
	if opts.non_options.len > 0 {
		opts.command = opts.non_options[0]
		opts.datafile_path = last(opts.non_options)
	}
	if option(args, ['-b', '--bins']) != '' {
		opts.bins = parse_range(option(args, ['-b', '--bins']))
	}
	opts.concurrency_flag = flag(args, ['-c', '--concurrent'])
	opts.exclude_flag = flag(args, ['-x', '--exclude'])
	opts.graph_flag = flag(args, ['-g', '--graph'])
	opts.verbose_flag = flag(args, ['-v', '--verbose'])
	opts.weighting_flag = flag(args, ['-w', '--weight'])
	opts.weight_ranking_flag = flag(args, ['-wr'])
	opts.uniform_bins = flag(args, ['-u', '--uniform'])
	opts.show_flag = flag(args, ['-s', '--show'])
	opts.expanded_flag = flag(args, ['-e', '--expanded'])
	opts.multiple_flag = flag(args, ['-m', '--multiple'])
	opts.break_on_all_flag = flag(args, ['-ma'])
	opts.combined_radii_flag = flag(args, ['-mc'])
	opts.append_settings_flag = flag(args, ['-ms'])
	opts.purge_flag = flag(args, ['-p', '--purge'])
	opts.balance_prevalences_flag = flag(args, ['-bp', '--balanced-prevalences'])
	if option(args, ['-a', '--attributes']) != '' {
		opts.number_of_attributes = parse_range(option(args, ['-a', '--attributes']))
	}
	if option(args, ['-f', '--folds']) != '' {
		opts.folds = option(args, ['-f', '--folds']).int()
	}
	if option(args, ['-r', '--reps']) != '' {
		opts.repetitions = option(args, ['-r', '--reps']).int()
	}
	if option(args, ['-m#']) != '' {
		opts.classifier_indices = parse_range(option(args, ['-m#']))
		println('opts.classifier_indices: ${opts.classifier_indices}')
	}
	opts.testfile_path = option(args, ['-t', '--test'])
	opts.outputfile_path = option(args, ['-o', '--output'])
	opts.classifierfile_path = option(args, ['-k', '--classifier'])
	opts.multiple_classify_options_file_path = option(args, ['-m', '--multiple'])
	opts.settingsfile_path = option(args, ['-ms'])
	return opts
}

// show_help
fn show_help(opts hamml.Options) string {
	return match opts.command {
		'rank' { rank_help }
		'query' { query_help }
		'analyze' { analyze_help }
		'append' { append_help }
		'make' { make_help }
		'orange' { orange_help }
		'verify' { verify_help }
		'cross' { cross_help }
		'explore' { explore_help }
		'validate' { validate_help }
		'display' { display_help }
		'examples' { examples_help }
		else { vhamml_help }
	}
}

// option returns the parameter following any of a list of options
fn option(args []string, what []string) string {
	mut found := false
	mut result := ''
	for arg in args {
		if found {
			result = arg
			break
		} else if arg in what {
			found = true
		}
	}
	return result
}

// flag returns true if a specific flag is found, false otherwise
fn flag(args []string, what []string) bool {
	for arg in args {
		if arg in what {
			return true
		}
	}
	return false
}

// analyze prints out to the console
fn analyze(mut opts hamml.Options) {
	opts.show_flag = true
	hamml.analyze_dataset(hamml.load_file(opts.datafile_path), opts)
}

// do_append appends instances in a file, to a classifier in a file specified
// by flag -k, and (optionally) stores the extended classifier in a file
// specified by -o. It displays the extended classifier on the console.
fn do_append(mut opts hamml.Options) ? {
	opts.show_flag = true
	ext_cl := hamml.append_instances(hamml.load_classifier_file(opts.classifierfile_path)?,
		hamml.load_instances_file(opts.datafile_path)?, opts)
	if opts.expanded_flag {
		println(ext_cl)
	}
}

// do_display displays information about the contents of a file
// for classifiers, datasets, or results of operations
fn do_display(opts hamml.Options) {
	// opts.show_flag = true
	hamml.display_file(opts.datafile_path, opts)
}

// query
fn do_query(mut opts hamml.Options) ? {
	mut cl := hamml.Classifier{}
	if opts.classifierfile_path == '' {
		mut ds := hamml.load_file(opts.datafile_path)
		cl = hamml.make_classifier(mut ds, opts)
	} else {
		cl = hamml.load_classifier_file(opts.classifierfile_path)?
	}
	qr := hamml.query(cl, opts)
	if opts.expanded_flag {
		println(qr)
	}
}

// verify
fn do_verify(mut opts hamml.Options) ? {
	opts.show_flag = true
	hamml.verify(opts)
}

// validate
fn do_validate(mut opts hamml.Options) ? {
	mut cl := hamml.Classifier{}
	if opts.classifierfile_path == '' {
		mut ds := hamml.load_file(opts.datafile_path)
		cl = hamml.make_classifier(mut ds, opts)
	} else {
		cl = hamml.load_classifier_file(opts.classifierfile_path)?
	}
	opts.show_flag = true
	var := hamml.validate(cl, opts)?
	if opts.expanded_flag {
		println(var)
	}
}

// cross
fn cross(mut opts hamml.Options) {
	opts.show_flag = true
	opts.random_pick = if opts.repetitions > 1 { true } else { false }
	hamml.cross_validate(hamml.load_file(opts.datafile_path), opts)
}

// do_explore
fn do_explore(mut opts hamml.Options) {
	opts.show_flag = true
	hamml.explore(hamml.load_file(opts.datafile_path), opts)
}

// orange
fn orange() {
}

// rank generates an array of attributes sorted according to their
// capacity to separate the classes, and displays it on the console.
// Optionally (-e flag) it prints out the RankingResult struct.
// Optionally (-o flag) it saves the RankingResult struct to a file.
fn rank(mut opts hamml.Options) {
	opts.show_flag = true
	ra := hamml.rank_attributes(hamml.load_file(opts.datafile_path), opts)
	if opts.expanded_flag {
		println(ra)
	}
}

// make generates a Classifier, and displays it on the console.
// Optionally (-e flag) it prints out the classifier struct.
// Optionally (-o flag) it saves the classifier file.
fn make(mut opts hamml.Options) ? {
	opts.show_flag = true
	mut ds := hamml.load_file(opts.datafile_path)
	cl := hamml.make_classifier(mut ds, opts)
	if opts.expanded_flag {
		println(cl)
	}
}

// parse_range takes a string like '3,6,8' and returns [3, 6, 8]
fn parse_range(arg string) []int {
	if arg == '' {
		return [0]
	}
	return arg.split(',').map(it.int())
}

// last returns the last element of a string array
fn last(array []string) string {
	return array[array.len - 1]
}

// print_array
fn print_array(array []string) {
	for line in array {
		println(line)
	}
}
