# RareSkills Assignments

Solutions to RareSkills Assignments using a Foundry-based template.

## What's Inside

- [Forge](https://github.com/foundry-rs/foundry/blob/master/forge): compile, test, fuzz, format, and deploy smart
  contracts
- [Forge Std](https://github.com/foundry-rs/forge-std): collection of helpful contracts and cheatcodes for testing
- [PRBTest](https://github.com/PaulRBerg/prb-test): modern collection of testing assertions and logging utilities
- [Prettier](https://github.com/prettier/prettier): code formatter for non-Solidity files
- [Solhint Community](https://github.com/solhint-community/solhint-community): linter for Solidity code

## Getting Started

If this is your first time with Foundry, check out the
[installation](https://github.com/foundry-rs/foundry#installation) instructions.

## Usage

This is a list of the most frequently needed commands.

### Copy .env

Add API keys for fork testing

```sh
$ cp .env.example .env
```

### Build

Compile the contracts:

```sh
$ npm run build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ npm run clean
```

### Testing

```sh
$ npm run test
```

### Coverage

Generate test coverage and output result to the terminal:

```sh
$ npm run test:coverage
```

### Gas Usage

Get a gas report:

```sh
$ forge test --match-contract CONTRACT_NAME --gas-report
```

### Lint

Lint the contracts:

```sh
$ npm run lint
```

### Format

Format the contracts:

```sh
$ npm run prettier:write
```

## Notes

Foundry uses [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) to manage dependencies. For detailed
instructions on working with dependencies, please refer to the
[guide](https://book.getfoundry.sh/projects/dependencies.html) in the book
