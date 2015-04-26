#!/usr/bin/env perl
use Mojo::UserAgent;
use Data::Dumper;
use feature 'say';
use List::MoreUtils qw( each_array );
use DBI;

my $base_url = "http://fabnews.ru/fablabs/list/fablabs/";
my $q = get_paginate_numbers($base_url);
say "Total pagination pages : ".$q;
my @a;
for my $i (1 .. $q) {
	my $curr_url = $base_url."page".$i."/";
	say "parsing page ".$i." :".$curr_url;
	my $b= table2hash ($base_url."page".$i."/");
	push(@a, @$b); 
	undef @$b;
}

# warn Dumper @a;

my $dbh = DBI->connect("dbi:SQLite:dbname=fablabs.db","","");
$dbh->{sqlite_unicode} = 1;

my $table = "fablabs";
# if not exists
create_db($dbh);

for (@a) {
	my $hash = prepare_sql($_);
	$dbh->do("INSERT INTO ".$table." (".$hash->{'fields'}.") VALUES (".$hash->{'values'}.")");
}

say "completed";

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
		$key_candidate =~ s/[\$#@~!&;:]+//g;
		my $key;
		if (grep { $match->{$_} eq $key_candidate } keys $match) {
			($key) = grep { $match->{$_} eq $key_candidate } keys $match;
			# say $key;
			$value = $i->find('td')->[1]->all_text;
			$h->{$key} = $value;
		}
		$value="";
		$key_candidate="";
	}
	# warn Dumper $h;
	return $h;
}

sub table2hash {
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

sub prepare_sql {
	my $hash = shift;
	my @fields;
	my @values;
	foreach my $key ( keys %$hash ) {
		push @fields, $key;
		push @values, "'".$hash->{$key}."'";
	}
	my $new_hash;
	$new_hash->{'fields'} = join(", ", @fields);
	$new_hash->{'values'} = join(", ", @values);
	return $new_hash;
}

sub create_db {
	my $dbh = shift;
	my $sql = <<'END_SQL';
CREATE TABLE fablabs (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100),
    location VARCHAR(150),
    email VARCHAR(100),
    phone VARCHAR(20),
    website VARCHAR(50),
    business_fields VARCHAR(150),
    foundation_date VARCHAR(50),
    fabnews_url VARCHAR(50),
    fabnews_rating VARCHAR(4),
    fabnews_subscribers VARCHAR(10)
    )
END_SQL
	$dbh->do($sql);	
	return 0;
}