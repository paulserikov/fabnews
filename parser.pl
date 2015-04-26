#!/usr/bin/env perl
use Mojo::UserAgent;
use Data::Dumper;
use feature 'say';
use List::MoreUtils qw( each_array );
use Deep::Encode;
# use utf8;    # comment it cause it can't parse cyrillic values so lab will have only email
use MongoDB;

my $test = parse_lab("http://fabnews.ru/fablabs/item/ufo/");
# deep_utf8_encode($test); 
warn Dumper $test;
my $client = MongoDB::MongoClient->new(host => 'localhost', port => 27017);
my $db = $client->get_database('fabnews');
my $labs = $db->get_collection('fablabs');
my $id = $labs->insert($test);
warn $id;

my $location = $labs->find_one( { "_id" => $id } );
warn Dumper $location->{location};

my $base_url = 'http://geocode-maps.yandex.ru/1.x/?geocode=';
# my $p = deep_utf8_encode($base_url);
my $ua = Mojo::UserAgent->new;
my $res = $ua->get($base_url . $location->{location})->res->body;
warn Dumper $res;


# my $location = $labs->find_one( { "_id" => $id } )->fields( { location => 1});   # MongoDB::Cursor
# while (my $row = $location->next) {
#     print "$row\n";
# }

# warn Dumper $location->next;




# my $all = $labs->find;
# warn Dumper $all;

# sub insert_into_mongo_collection {
# 	my ($database, $host, $port, $collection, $arr_of_hashes) = (@_);
# 	my $client = MongoDB::MongoClient->new(host => $host, port => $port);
# 	my $db = $client->get_database($database);
# 	my $labs = $db->get_collection($collection);
# 	for (@$arr_of_hashes) {
# 		my $id = $labs->insert($_);
# 	}
# 	say "done";
# }



# return urls to all pages at pagination
sub get_all_labs {	
my $base_url = shift;;
my $q = get_paginate_numbers($base_url);
say "Total pagination pages : ".$q;
my @a;
	for my $i (1 .. $q) {
		my $curr_url = $base_url."page".$i."/";
		say "parsing page ".$i." :".$curr_url;
		my $b= table2array_of_hashes ($base_url."page".$i."/");  # hash to store 
		push(@a, @$b); 
		undef @$b;
	}
return \@a;
}


sub get_paginate_numbers {
	my $url = shift;
	my $ua = Mojo::UserAgent->new;
	my $pagination = $ua->get($url)->res->dom->at('.pagination');
	my @a = $pagination->find('ul')->each;
	my @ref = $a[1]->find('li')->each;
	my $q = scalar @ref;
	my $last_link = $ref[$q-1]->at('a[href]')->attr('href');    # target link with page
	$last_link =~ /page(\d{1})/;							
	return $1;
}

# parse_lab() use Mojo::UserAgent and Mojo::Dom to extract info about lab
	# be carefull with encodings!
	# definition: parse_lab($url);
	# Result will  be like this:
	# {
	 #          'business_fields' => '3d печать, CAM',
	 #          'foundation_date' => '03 Декабрь 2013',
	 #          'location' => 'Россия, Ростов-на-Дону, ул. Мильчакова 5/2 лаб.5а',
	 #          'phone' => '+79885851900',
	 #          'email' => 'team@fablab61.ru',
	 #          'website' => 'http://fablab61.ru/'
	 #        };
sub parse_lab {
	my $url = shift;
	say "url received: ".$url;
	my $h = {};
	my $ua = Mojo::UserAgent->new;
	my $table_dom = $ua->get($url)->res->dom->at('.company-profile-table');
	my $match = {
	foundation_date => "Дата основания",
	website => "Сайт",
	business_fields => "Виды деятельности",
	location => "Местоположение",
	email => "E-mail",
	phone => "Телефон"
	};
	for my $i ($table_dom->find('tr')->each) {
		my $value="";
		my $key_candidate = $i->find('td')->[0]->all_text;
		# say $key_candidate;

		my $val_candidate = $i->find('td')->[1]->all_text;
		# say $val_candidate;

		$key_candidate =~ s/[\$#@~!&;:]+//g;
		my $key;
		# say $key_candidate;
		if (grep { $match->{$_} eq $key_candidate } keys $match) {
			($key) = grep { $match->{$_} eq $key_candidate } keys $match;
			# say "future key": $key;
			$value = $i->find('td')->[1]->all_text;
			$h->{$key} = $value;
		}
		$value="";
		$key_candidate="";
	}
	return $h;
}

# This method is doing parsing page like http://fabnews.ru/fablabs/list/fablabs/page2/
# E

sub table2array_of_hashes {
	##
	my $url = shift;  # receive Mojo::DOM object
	my $ua = Mojo::UserAgent->new;
	my $dom = $ua->get($url)->res->dom->at('table');
	
	my @fields = ("name", "fabnews_subscribers", "fabnews_rating");
	
	#### uncomment it if you want automatically fill fields from table. please note that it will be in russian
	# my @fields;
	# for ($dom->find('thead th')->each) {
	# 	push @fields, $_->text;
	# }
	# warn "Fields: ". Dumper \@fields;

	my $h = {};
	my @array_of_hashes;

	for my $i ($dom->find('tbody tr')->each) {
		my $hash2 = {};
		my @values = $i->find('td')->each;					# html values				
		my $it = each_array(@fields, @values );
		while ( my ($x, $y) = $it->() ) {			
			if ($x eq "name") {
					my ($name, $last_post) = split('Последний пост из блога:', $y->all_text);
					$h->{'fabnews_url'}=$y->at('a[href]')->attr('href');
					$h->{$x}=$name;
					say $name; 
					# warn Dumper $h;
					$hash2 = parse_lab($h->{'fabnews_url'}."/");
					# my %hash3 = (%hash1, %hash2);
				} else {
					$h->{$x}=$y->all_text; 					# could be text, all_text
				}
		}
		my $merged_hash = { %$h, %$hash2 };
		push @array_of_hashes, $merged_hash;
		$h = {};
		$hash2 = {};
		$merged_hash ={};
	}

	return \@array_of_hashes;
}
