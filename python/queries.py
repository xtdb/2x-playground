import psycopg2
import sqlalchemy
import pandas

query3_fails = """SELECT users.name, users.age, trades.trade_date, trades.matt_nums
          FROM users
          JOIN trades ON users.name = trades.trade_user
          WHERE users.age > 30"""

query4_works = """SELECT users.name, users.age, trades.trade_date
          FROM users
          JOIN trades ON users.name = trades.trade_user
          WHERE users.age > 30"""

query5_fails = """SELECT users.name, users.age, trades.dan_map
          FROM users
          JOIN trades ON users.name = trades.trade_user
          WHERE users.age > 30"""

query6_works = """SELECT trades.trade_user, trades.dan_map, trades.trade_date
          FROM trades WHERE trades.exchange = 'juxt'"""

query2 = """SELECT trades.trade_user, trades.trade_date, trades.bird
          FROM trades WHERE trades.exchange = 'juxt'"""

def dbapi_plain():
    with psycopg2.connect("dbname=test user=test password=test host=localhost sslmode=disable") as conn:
        with conn.cursor() as cur:
            cur.execute(query2)
            print(cur.fetchall())

def sqlalchemy_core():
    engine = sqlalchemy.create_engine("postgresql://test:test@localhost/test", use_native_hstore=False)
    engine.echo = True
    with engine.connect() as conn:
        print(conn.execute(query2))
    pass

def sqlalchemy_core2():
    q = """SELECT users.name FROM users"""
    q2 = """SELECT trades.trade_user, trades.trade_date
          FROM trades WHERE trades.trade_user = 'Dan'"""
    q3 = """SELECT trades.trade_user, trades.dan_map, trades.trade_date
          FROM trades WHERE trades.trade_user = 'Dan'"""
    q4 = """SELECT trades.trade_user, trades.trade_date, trades.bird
          FROM trades WHERE trades.exchange = 'juxt'"""

    engine = sqlalchemy.create_engine("postgresql://test:test@localhost/test", use_native_hstore=False)
    engine.echo = True
    with engine.connect() as conn:
        result = conn.execute(q4)
        print(result.rowcount, "results...")
        for row in result:
            print(row['bird']['iam'])
            # print(type(row['dan_map']))
            # print(row['dan_map']['iam'])
    pass

def pandas_example():
    engine = sqlalchemy.create_engine("postgresql://test:test@localhost/test", use_native_hstore=False)
    df = pandas.read_sql_query(query2, engine)

    # types are narrowed if json numbers are present
    # bignums get force casted tho, lossy.
    print("\ndataframe sees these types:")
    print(df.dtypes)
    # print("dataframe:")
    # print(df)
    print("\njson:")
    print(df.to_json)


# dbapi_plain()
# sqlalchemy_core2()
pandas_example()
