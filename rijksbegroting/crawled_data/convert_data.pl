#!/usr/bin/env perl

# Script to convert the output of the scraped data from rijksbegroting.nl into
# csv files which can be used for the Nederlandse Rijksbegroting Visualisatie.

use strict;
use warnings;
use utf8;
use JSON;
use Text::CSV;


######################
# OPTIONS
######################
# The years that need to be processed.
my @years = (2012, 2013, 2014);

# The departments are sorted based on an awesome mix of Roman numerals and characters. This order needs
# to be manually specified to keep the data nicely sorted when saving it to the csv files.
my @custom_order = qw(I IIA IIB III IV V VI VII VIII IX IXA IXB X XI XII XIII XV XVI XVII XVIII A B C F H J);
my %order = map +($custom_order[$_] => $_), 0 .. $#custom_order;

######################
# FUNCTIONS
######################
# Custom sorting function for the Roman numeral/character mix of the departments.
sub custom_sort {
        my @x = split('_', $a);
        my @y = split('_', $b);
        return $order{$x[0]} <=> $order{$y[0]};
}

# Save expenses budgets to csv.
# $data contains the collected budgets, $money_type can be either 'uitgaven' (expenses) or 'inkomsten' (income).
sub save_data {
        my ($data, $money_type, $column_names, $csv_out) = @_;

        # Convert the datia in the hash to arrays which each represent a row which will be written to the csv.
        my %data = %{$data};
        my @data_rows;
        push @data_rows, $column_names;
        # Loop over all departments, sorted by their Roman numeral/character ID.
        for my $department (sort custom_sort keys %data) {
                # Loop over all bureaus, sorted by their numeric ID.
                for my $bureau (sort {(split("_", $a))[0] <=> (split("_", $b))[0]} keys $data{$department}) {
                        my @budgets;
                        for my $year (@years) {
                                my $ar_budget = $data{$department}{$bureau}{$year};
                                my @budget;
                                # Some departments are not listed in every year's budget.
                                # If it doesn't exist then set the budget to 0.
                                if (defined $ar_budget) {
                                        @budget = @{$ar_budget};
                                }
                                else {
                                        push @budget, 0;
                                        #foreach (@budget_types) {
                                        #        push @budget, 0;
                                        #}
                                }
                                push @budgets, @budget;
                        }
                        # Separate the code and name of the department and bureau keys.
                        my @department = split('_', $department);
                        my @bureau = split('_', $bureau);
                        push @data_rows, [$department[0], $department[1], $bureau[0], $bureau[1], @budgets];
                }
        }

        open(my $fh, ">:encoding(utf8)", "nl_rijksbegroting_" . $money_type . ".csv") or die "nl_rijksbegroting_" . $money_type . ".csv: $!\n";
        $csv_out->print ($fh, $_) for @data_rows;
        close $fh;
}

# Some bureau names and codes have changed over the years. This subroutine combines those bureaus again.
# Note: this is not perfect, but works for now. The department data should be taken into account to make
# sure that some frequently occurring names like 'Algemeen' and 'Apparaat' (with potentially the same code)
# don't interfere.
sub rename_bureau {
    my ($name, $code) = @_;
    return ('Wetgeving en controle Eerste Kamer', $code) if ($name eq 'Wetgeving en controle EK');
    return ('Uitgaven ten behoeve van leden en oud-leden Tweede Kamer, alsmede leden van het Europees Parlement', $code) if ($name eq 'Uitgaven tbv van (oud) leden Tweede Kamer en leden EP');
    return ('Wetgeving en controle Tweede Kamer', $code) if ($name eq 'Wetgeving/controle TK');
    return ('Wetgeving en controle Eerste en Tweede Kamer', $code) if ($name eq 'Wetgeving/controle EK en TK');
    return ('Kabinet van de Gouverneur van Sint Maarten', $code) if ($name eq 'Kabinet van de Gouverneur van St. Maarten');
    return ('Kabinet van de Koning/Koningin', $code) if ($name eq 'Kabinet der Koningin' or $name eq 'Kabinet van de Koning');
    return ('Commissie van toezicht betreffende de inlichtingen- en veiligheidsdiensten', $code) if ($name eq 'Commissie van Toezicht betreffende de Inlichtingen- en Veiligheidsdiensten');
    return ('Eenheid van het algemeen regeringsbeleid', $code) if ($name eq 'Bevorderen van de eenheid van het algemeen regeringsbeleid');
    return ('Veiligheid en stabiliteit', $code) if ($name eq 'Grotere veiligheid en stabiliteit, effectieve humanitaire hulpverlening en goed bestuur');
    return ('Geheim', 9) if ($name eq 'Geheim' and $code == 5);
    return ('Nominaal en onvoorzien', 10) if ($name eq 'Nominaal en onvoorzien' and $code == 6);
    return ('Apparaat', 11) if ($name eq 'Apparaat' and $code == 7);
    return ('Apparaat', $code) if ($name eq 'Algemeen' and $code == 11);
    return ('Apparaatsuitgaven kerndepartement', $code) if ($name eq 'Apparaat kerndepartement');
    return ('Algemene Inlichtingen- en Veiligheidsdienst', $code) if ($name eq 'Algemene Inlichtingen en Veiligheidsdienst');
    return ('Exportkredietverzekeringen,-garanties en investeringsverzekeringen', $code) if ($name eq 'Exportkrediet- en investeringsgaranties');
    return ('Apparaatsuitgaven Kerndepartement', $code) if ($name eq 'Apparaatuitgaven van het Kerndepartement');
    return ('Natuur en Regio', $code) if ($name eq 'Natuur en regio');
    return ('Een excellent ondernemingsklimaat', $code) if ($name eq 'Een excellentondernemingsklimaat');
    return ('Langdurige zorg en ondersteuning', $code) if ($name eq 'Maatschappelijke ondersteuning en langdurige zorg');
    return ('Beheer materiële activa', $code) if ($name eq 'Beheer materiele activa');
    return ('Bijdragen andere begrotingen Rijk', $code) if ($name eq 'Bijdragen t.l.v. begrotingen Hoofdstuk XII');
    return ($name, $code);
}

sub rename_department {
    my ($name, $code) = @_;
    return ('Economische Zaken', $code) if ($name eq 'Economische Zaken (Landbouw en innovatie)');
    return ($name, $code)
}

######################
# SCRIPT
######################
open(my $fh, '<', 'scraped_data.json');

my $json_text;
local $/;
$json_text .= <$fh>;
close $fh;
my @data = @{decode_json($json_text)};

my %data_income;
my %data_expenses;

for my $row (@data) {
    my %row = %$row;
    my ($bureau_name, $bureau_code) = rename_bureau($row{bureau_name}, $row{bureau_code});
    my ($department_name, $department_code) = rename_department($row{department_name}, $row{department_code});
    $data_income{"${department_code}_$department_name"}{"${bureau_code}_$bureau_name"}{$row{year}} = [$row{ontvangsten}];
    $data_expenses{"${department_code}_$department_name"}{"${bureau_code}_$bureau_name"}{$row{year}} = [$row{uitgaven}];
}

my $csv_out = Text::CSV->new({
        sep_char  => ',',
        binary    => 1, # Allow special character. Always set this
        auto_diag => 1 # Report irregularities immediately
});

# Print newline at end of line when creating the output csv.
$csv_out->eol ("\n");

my @column_names = ('Agency Code', 'Agency Name', 'Bureau Code', 'Bureau Name', '2012', '2013', '2014');

# Save the expenses and income data to csv.
&save_data(\%data_expenses, 'uitgaven', \@column_names, $csv_out);
&save_data(\%data_income, 'inkomsten', \@column_names, $csv_out);

print "Finished processing\n";
