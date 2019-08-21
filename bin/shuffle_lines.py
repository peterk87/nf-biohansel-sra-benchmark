#!/usr/bin/env python
import random
import click

@click.command()
@click.option('--input-file', required=True)
@click.option('--output-file', required=True)
@click.option('--random-seed', default=42)
def shuffle_lines(input_file, output_file, random_seed):
    random.seed(random_seed)
    with open(input_file) as fin, open(output_file, 'w') as fout:
        lines = [l.strip() for l in fin if l.strip()]
        random.shuffle(lines)
        for l in lines:
            fout.write(f'{l}\n')

if __name__ == '__main__':
    shuffle_lines()
